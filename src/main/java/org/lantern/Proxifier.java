package org.lantern;

import java.io.File;
import java.io.IOException;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.SystemUtils;
import org.lantern.win.WinInet;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.sun.jna.Pointer;
import com.sun.jna.platform.win32.Kernel32;
import com.sun.jna.ptr.IntByReference;

/**
 * Class that handles turning proxying on and off for all platforms.
 */
public class Proxifier {
    
    public static class ProxyConfigurationError extends Exception {}
    public static class ProxyConfigurationCancelled extends ProxyConfigurationError {};
    
    private static final Logger LOG = 
        LoggerFactory.getLogger(Proxifier.class);
    
    /**
     * File external processes can use to determine if Lantern is currently
     * proxying traffic. Useful for things like the FireFox extensions.
     */
    private static final File LANTERN_PROXYING_FILE =
        new File(LanternUtils.configDir(), "lanternProxying");
    
    private static String proxyServerOriginal;
    private static String proxyEnableOriginal = "0";

    private static final MacProxyManager mpm = 
        new MacProxyManager("testId", 4291);
    
    private static final String WINDOWS_REGISTRY_PROXY_KEY = 
        "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings";
    
    private static final String ps = "ProxyServer";
    private static final String pe = "ProxyEnable";
    
    private static final String LANTERN_PROXY_ADDRESS = "127.0.0.1:"+
        LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
    
    private static final File PROXY_ON = new File("proxy_on.pac");
    private static final File PROXY_OFF = new File("proxy_off.pac");
    
    static {
        if (SystemUtils.IS_OS_MAC_OSX) {
            final File Lantern = new File("Lantern");
            if (!Lantern.isFile()) {
                LOG.info("Creating hard link to osascript...");
                final String result = 
                    mpm.runScript("ln", "/usr/bin/osascript", "Lantern");
                LOG.info("Result of script is: {}", result);
            } else {
                LOG.info("Appears to already be a link to osascript");
            }
        }
        LANTERN_PROXYING_FILE.delete();
        LANTERN_PROXYING_FILE.deleteOnExit();
        if (!PROXY_ON.isFile()) {
            final String msg = 
                "No pac at: "+PROXY_ON.getAbsolutePath() +"\nfrom: " +
                new File(".").getAbsolutePath();
            LOG.error(msg);
            throw new IllegalStateException(msg);
        }
        if (!PROXY_OFF.isFile()) {
            final String msg = 
                "No pac at: "+PROXY_OFF.getAbsolutePath() +"\nfrom: " +
                new File(".").getAbsolutePath();
            LOG.error(msg);
            throw new IllegalStateException(msg);
        }
        LOG.info("Both pac files are in their expected locations");

        // We always want to stop proxying on shutdown -- doesn't hurt 
        // anything in the case where we never proxied in the first place.
        // if there is a Ui we let the Ui handle it. 
        if (!LanternHub.settings().isUiEnabled()) {
            final Thread hook = new Thread(new Runnable() {
                @Override
                public void run() {
                    try {
                        stopProxying();
                    } catch (final Proxifier.ProxyConfigurationError e) {
                        LOG.error("Failed to unconfigure proxy: {}", e);
                    }
                }
            }, "Unset-Web-Proxy-Thread");
            Runtime.getRuntime().addShutdownHook(hook);
        }
    }
    
    private static final File ACTIVE_PAC = 
        new File(LanternUtils.configDir(), "proxy.pac");
    
    public static void startProxying() throws ProxyConfigurationError {
        if (isProxying()) {
            LOG.info("Already proxying!");
            return;
        }
        
        if (!LanternUtils.shouldProxy()) {
            LOG.info("Not proxying in current mode...");
        }

        LOG.info("Autoconfiguring local to proxy Lantern");
        if (SystemUtils.IS_OS_MAC_OSX) {
            proxyOsx();
        } else if (SystemUtils.IS_OS_WINDOWS) {
            proxyWindows();
        } else if (SystemUtils.IS_OS_LINUX) {
            // TODO: proxyLinux();
        }
        // success
        try {
            if (!LANTERN_PROXYING_FILE.isFile() &&
                !LANTERN_PROXYING_FILE.createNewFile()) {
                LOG.error("Could not create proxy file?");
            }
        } catch (final IOException e) {
            LOG.error("Could not create proxy file?", e);
        }
        LanternHub.eventBus().post(new ProxyingEvent(true));
    }
    
    public static void stopProxying() throws ProxyConfigurationError {
        if (!isProxying()) {
            return; 
        }

        LOG.info("Unproxying Lantern");
        if (SystemUtils.IS_OS_MAC_OSX) {
            unproxyOsx();
        } else if (SystemUtils.IS_OS_WINDOWS) {
            unproxyWindows();
        } else if (SystemUtils.IS_OS_LINUX) {
            // TODO: unproxyLinux();
        }
        LANTERN_PROXYING_FILE.delete();
        LanternHub.eventBus().post(new ProxyingEvent(false));
    }

    public static boolean isProxying() {
        return LANTERN_PROXYING_FILE.isFile();
    }
    
    private static void proxyOsx() throws ProxyConfigurationError {
        configureOsxProxyPacFile();
        proxyOsxViaScript();
    }

    public static void proxyOsxViaScript() throws ProxyConfigurationError {
        proxyOsxViaScript(true);
    }
    
    private static void proxyOsxViaScript(final boolean proxy) throws ProxyConfigurationError {
        final String onOrOff;
        if (proxy) {
            onOrOff = "on";
        } else {
            onOrOff = "off";
        }
        
        boolean locked = false;
        try {
            locked = osxPrefPanesLocked();
        } catch (final IOException e) {
            locked = false;
        }
        
        String applescriptCommand = 
            "do shell script \"./configureNetworkServices.bash "+
            onOrOff;
        
        if (locked) {
            applescriptCommand +="\" with administrator privileges without altering line endings";
        } else {
            applescriptCommand +="\" without altering line endings";
        }

        // XXX @myleshorton can we skip this when there's no need to change
        // system proxy settings, e.g. an unproxy call after a proxy call was
        // canceled, or vice versa?
        final String result = 
            //mpm.runScript("osascript", "-e", applescriptCommand);
            mpm.runScript("./Lantern", "-e", applescriptCommand);
        LOG.info("Result of script is: {}", result);
        
        if (result.contains("canceled")) {
            throw new ProxyConfigurationCancelled();
        }
    }

    /**
     * Uses a pack file to manipulate browser's use of Lantern.
     */
    private static void configureOsxProxyPacFile() {
        try {
            FileUtils.copyFile(PROXY_ON, ACTIVE_PAC);
        } catch (final IOException e) {
            LOG.error("Could not copy pac file?", e);
        }
    }


    private static void proxyWindows() {
        if (!SystemUtils.IS_OS_WINDOWS) {
            LOG.info("Not running on Windows");
            return;
        }
        
        // We first want to read the start values so we can return the
        // registry to the original state when we shut down.
        proxyServerOriginal = 
            WindowsRegistry.read(WINDOWS_REGISTRY_PROXY_KEY, ps);
        proxyEnableOriginal = 
            WindowsRegistry.read(WINDOWS_REGISTRY_PROXY_KEY, pe);
        
        final String proxyServerUs = "127.0.0.1:"+
            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
        final String proxyEnableUs = "1";

        // OK, we do one final check here. If the original proxy settings were
        // already configured for Lantern for whatever reason, we want to 
        // change the original to be the system defaults so that when the user
        // stops Lantern, the system actually goes back to its original pre-
        // lantern state.
        if (proxyServerOriginal.equals(LANTERN_PROXY_ADDRESS) && 
            proxyEnableOriginal.equals(proxyEnableUs)) {
            proxyEnableOriginal = "0";
        }
                
        LOG.info("Setting registry to use Lantern as a proxy...");
        final int enableResult = 
            WindowsRegistry.writeREG_SZ(WINDOWS_REGISTRY_PROXY_KEY, ps, proxyServerUs);
        final int serverResult = 
            WindowsRegistry.writeREG_DWORD(WINDOWS_REGISTRY_PROXY_KEY, pe, proxyEnableUs);
        
        if (enableResult != 0) {
            LOG.error("Error enabling the proxy server? Result: "+enableResult);
        }
    
        if (serverResult != 0) {
            LOG.error("Error setting proxy server? Result: "+serverResult);
        }
        
        refreshWindowsInet();
    }

    private static void refreshWindowsInet() {
        Pointer hInternet = null;
        IntByReference len = new IntByReference();
        if (!WinInet.INSTANCE.InternetSetOption(hInternet,WinInet.INTERNET_OPTION_PROXY_SETTINGS_CHANGED, (Pointer)null, len)){
            LOG.error("InternetSetOption failed!:" + Kernel32.INSTANCE.GetLastError());
        }
        if (!WinInet.INSTANCE.InternetSetOption(hInternet,WinInet.INTERNET_OPTION_REFRESH, (Pointer)null, len)){
            LOG.error("InternetSetOption failed!:" + Kernel32.INSTANCE.GetLastError());
        }
        LOG.info("InternetSetOption appeared to succeed?");
    }

    public static void unproxy() throws ProxyConfigurationError {
        if (SystemUtils.IS_OS_WINDOWS) {
            // We first want to read the start values so we can return the
            // registry to the original state when we shut down.
            proxyServerOriginal = 
                WindowsRegistry.read(WINDOWS_REGISTRY_PROXY_KEY, ps);
            if (proxyServerOriginal.equals(LANTERN_PROXY_ADDRESS)) {
                unproxyWindows();
            }
        } else if (SystemUtils.IS_OS_MAC_OSX) {
            unproxyOsx();
        } else {
            LOG.warn("We don't yet support proxy configuration on other OSes");
        }
    }
    
    protected static void unproxyWindows() {
        LOG.info("Resetting Windows registry settings to original values.");
        final String proxyEnableUs = "1";
        
        // On shutdown, we need to check if the user has modified the
        // registry since we originally set it. If they have, we want
        // to keep their setting. If not, we want to revert back to 
        // before Lantern started.
        final String proxyServer = 
            WindowsRegistry.read(WINDOWS_REGISTRY_PROXY_KEY, ps);
        final String proxyEnable = 
            WindowsRegistry.read(WINDOWS_REGISTRY_PROXY_KEY, pe);
        
        if (proxyServer.equals(LANTERN_PROXY_ADDRESS)) {
            LOG.info("Setting proxy server back to: {}", 
                proxyServerOriginal);
            WindowsRegistry.writeREG_SZ(WINDOWS_REGISTRY_PROXY_KEY, ps, 
                proxyServerOriginal);
            LOG.info("Successfully reset proxy server");
        }
        
        if (proxyEnable.equals(proxyEnableUs)) {
            LOG.info("Setting proxy enable back to 0");
            WindowsRegistry.writeREG_DWORD(WINDOWS_REGISTRY_PROXY_KEY, pe, "0");
            LOG.info("Successfully reset proxy enable");
        }
        
        refreshWindowsInet();
        LOG.info("Done resetting the Windows registry");
    }

    private static void unproxyOsx() throws ProxyConfigurationError {
        unproxyOsxPacFile();
        unproxyOsxViaScript();
    }
    
    static void unproxyOsxViaScript() throws ProxyConfigurationError {
        proxyOsxViaScript(false);
    }
    
    private static void unproxyOsxPacFile() {
        try {
            LOG.info("Unproxying!!");
            FileUtils.copyFile(PROXY_OFF, ACTIVE_PAC);
            LOG.info("Done unproxying!!");
        } catch (final IOException e) {
            LOG.error("Could not copy pac file?", e);
        }
    }
    
    /**
     * Calls out to AppleScript to check if the user has the security setting
     * checked to require an administrator password to unlock preferences.
     * 
     * @return <code>true</code> if the user has the setting checked, otherwise
     * <code>false</code>.
     * @throws IOException If there was a scripting error reading the 
     * preferences setting.
     */
    public static boolean osxPrefPanesLocked() throws IOException {
        final String script = 
            "tell application \"System Events\"\n"+
            "    tell security preferences\n"+
            "        get require password to unlock\n"+
            "    end tell\n"+
            "end tell\n";
        final String result = 
            mpm.runScript("osascript", "-e", script);
        LOG.info("Result of script is: {}", result);

        if (StringUtils.isBlank(result)) {
            LOG.error("No result from AppleScript");
            return false;
        }
        
        // Make sure it's 
        if (LanternUtils.isTrue(result)) {
            return true;
        } else if (LanternUtils.isFalse(result)) {
            return false;
        } else {
            final String msg = "Got unexpected result from AppleScript: "+result;
            LOG.error(msg);
            throw new IOException(msg);
        }
    }
}
