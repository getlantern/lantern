package org.lantern;

import java.io.File;
import java.io.IOException;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.SystemUtils;
import org.eclipse.swt.SWT;
import org.lantern.win.WinProxy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

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
        new File(LanternConstants.CONFIG_DIR, "lanternProxying");
    
    private static String proxyServerOriginal = "";

    private static boolean interactiveUnproxyCalled;

    private static final MacProxyManager mpm = 
        new MacProxyManager("testId", 4291);
    
    private static final String LANTERN_PROXY_ADDRESS = "127.0.0.1:"+
        LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
    
    private static final File PROXY_ON = new File("proxy_on.pac");
    private static final File PROXY_OFF = new File("proxy_off.pac");
    
    private static final WinProxy WIN_PROXY = new WinProxy(LanternConstants.CONFIG_DIR);
    
    static {
        final class Subscriber {
            @Subscribe
            public void onQuit(final QuitEvent quit) {
                LOG.info("Got quit event!");
                interactiveUnproxy();
            }
        }
        LanternHub.register(new Subscriber());
        
        if (SystemUtils.IS_OS_MAC_OSX) {
            final File Lantern = new File("Lantern");
            if (!Lantern.isFile()) {
                LOG.info("Creating hard link to osascript...");
                try {
                    final String result = 
                        mpm.runScript("ln", "/usr/bin/osascript", "Lantern");
                    LOG.info("Result of script is: {}", result);
                } catch (final IOException e) {
                    LOG.warn("Error creating hard link!!", e);
                }
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
        // If there is a UI we let the UI handle it. 
        final Thread hook = new Thread(new Runnable() {
            @Override
            public void run() {
                interactiveUnproxy();
            }
        }, "Unset-Web-Proxy-Thread");
        Runtime.getRuntime().addShutdownHook(hook);
    }
    
    private static final File ACTIVE_PAC = 
        new File(LanternConstants.CONFIG_DIR, "proxy.pac");
    
    public static void startProxying() throws ProxyConfigurationError {
        startProxying(false);
    }
    
    private static void startProxying(final boolean force) 
        throws ProxyConfigurationError {
        if (isProxying() && !force) {
            LOG.info("Already proxying!");
            return;
        }
        
        if (!LanternUtils.shouldProxy()) {
            LOG.info("Not proxying in current mode...");
            return;
        }

        // Always update the pac file to make sure we've got all the latest
        // entries.
        PacFileGenerator.generatePacFile(
            LanternHub.whitelist().getEntriesAsStrings(), PROXY_ON);
        
        copyPacFile();
        
        LOG.info("Autoconfiguring local to proxy Lantern");
        if (SystemUtils.IS_OS_MAC_OSX) {
            proxyOsx();
        } else if (SystemUtils.IS_OS_WINDOWS) {
            proxyWindows();
        } else if (SystemUtils.IS_OS_LINUX) {
            proxyLinux();
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
    
    public static void interactiveUnproxy() {
        if (Proxifier.interactiveUnproxyCalled) {
            LOG.info("Interactive unproxy already called!");
            return;
        }
        Proxifier.interactiveUnproxyCalled = true;
        if (!LanternHub.settings().isUiEnabled()) {
            try {
                stopProxying();
            } catch (final Proxifier.ProxyConfigurationError e) {
                LOG.error("Failed to unconfigure proxy: {}", e);
            }
        } else {
            // The following often happens as the result of the quit event
            // because we need the UI to still be up to interact with the 
            // user -- that's not always the case with System.exit/shutdown
            // hooks.
            boolean finished = false;
            while (!finished) {
                try {
                    Proxifier.stopProxying();
                    finished = true;
                } catch (final Proxifier.ProxyConfigurationError e) {
                    LOG.error("Failed to unconfigure proxy.");
                    // XXX i18n
                    final String question = "Failed to change the system proxy settings.\n\n" + 
                    "If Lantern remains as the system proxy after being shut down, " + 
                    "you will need to manually change the system's network proxy settings " + 
                    "in order to access the web.\n\nTry again?";
                    
                    // TODO: Don't think this will work on Linux.
                    final int response = LanternHub.dashboard().askQuestion("Proxy Settings", question,
                        SWT.APPLICATION_MODAL | SWT.ICON_WARNING | SWT.RETRY | SWT.CANCEL);
                    if (response == SWT.CANCEL) {
                        finished = true;
                    }
                    else {
                        LOG.info("Trying again");
                    }
                }
            }
        }
    }

    public static void stopProxying() throws ProxyConfigurationError {
        if (!isProxying()) {
            LOG.info("Ignoring call since we're not proxying");
            return; 
        }

        LOG.info("Unproxying Lantern");
        if (SystemUtils.IS_OS_MAC_OSX) {
            unproxyOsx();
        } else if (SystemUtils.IS_OS_WINDOWS) {
            unproxyWindows();
        } else if (SystemUtils.IS_OS_LINUX) {
            unproxyLinux();
        }
        LANTERN_PROXYING_FILE.delete();
        LanternHub.eventBus().post(new ProxyingEvent(false));
    }

    public static boolean isProxying() {
        return LANTERN_PROXYING_FILE.isFile();
    }
    
    private static void proxyLinux() throws ProxyConfigurationError {
        final String path = PROXY_ON.toURI().toASCIIString();

        try {
            final String result1 = 
                mpm.runScript("gsettings", "set", "org.gnome.system.proxy", 
                    "mode", "'auto'");
            LOG.info("Result of Ubuntu gsettings mode call: {}", result1);
            final String result2 = 
                mpm.runScript("gsettings", "set", "org.gnome.system.proxy", 
                    "autoconfig-url", path);
            LOG.info("Result of Ubuntu gsettings pac file call: {}", result2);
        } catch (final IOException e) {
            LOG.warn("Error calling Ubuntu proxy script!", e);
            throw new ProxyConfigurationError();
        }
    }
    
    private static void proxyOsx() throws ProxyConfigurationError {
        proxyOsxViaScript(true);
    }
    
    private static void proxyOsxViaScript(final boolean proxy) 
        throws ProxyConfigurationError {
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
        try {
            final String result = //mpm.runScript("osascript", "-e", applescriptCommand);
                mpm.runScript("./Lantern", "-e", applescriptCommand);
            LOG.info("Result of script is {}", result);
        } catch (final IOException e) {
            final String msg = e.getMessage();
            if (!msg.contains("canceled")) {
                // Could just be another language here...
                LOG.error("Script failure with unknown message: "+msg, e);
            } else {
                LOG.info("Exception running script", e);
            }
            LanternHub.settings().setSystemProxy(false);
            throw new ProxyConfigurationCancelled();
        }
    }

    /**
     * Uses a pac file to manipulate browser's use of Lantern.
     */
    private static void copyPacFile() {
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
        
        final String url = 
            ACTIVE_PAC.toURI().toASCIIString().replace("file:/", "file://");
        LOG.info("Using pac path: {}", url);
        
        WIN_PROXY.setPacFile(url);
        
        /*
        // We first want to read the start values so we can return the
        // registry to the original state when we shut down.
        final String curProxy = proxy.getProxy();
        final String proxyServerUs = "127.0.0.1:"+
            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;

        // OK, we do one final check here. If the original proxy settings were
        // already configured for Lantern for whatever reason, we want to 
        // change the original to be the system defaults so that when the user
        // stops Lantern, the system actually goes back to its original pre-
        // lantern state.
        if (curProxy.equals(LANTERN_PROXY_ADDRESS)) {
            // Only set the original proxy server to blank if it's not already
            // set.
            if (StringUtils.isBlank(proxyServerOriginal)) {
                proxyServerOriginal = "";
            }
        } else {
            proxyServerOriginal = curProxy;
        }
                
        LOG.info("Setting registry to use Lantern as a proxy...");
        
        if (proxy.proxy(proxyServerUs)) {
            LOG.info("Successfully reset proxy server");
        } else {
            LOG.warn("Error setting the proxy server?");
        }
        */
    }

    protected static void unproxyWindows() {
        //LOG.info("Resetting Windows registry settings to original values.");
        LOG.info("Unproxying windows");
        WIN_PROXY.noPacFile();
        
        /*
        // On shutdown, we need to check if the user has modified the
        // registry since we originally set it. If they have, we want
        // to keep their setting. If not, we want to revert back to 
        // before Lantern started.
        final String proxyServer = proxy.getProxy();
        
        if (proxyServer.equals(LANTERN_PROXY_ADDRESS)) {
            LOG.info("Setting proxy server back to: {}", 
                proxyServerOriginal);
            if (proxy.proxy(proxyServerOriginal)) {
                LOG.info("Successfully reset proxy server");
            } else {
                LOG.warn("Error setting the proxy server?");
            }
        }
        LOG.info("Done resetting the Windows registry");
        */
    }
    
    private static void unproxyLinux() throws ProxyConfigurationError {
        try {
            final String result1 = 
                mpm.runScript("gsettings", "set", "org.gnome.system.proxy", 
                    "mode", "'none'");
            LOG.info("Result of Ubuntu gsettings mode call: {}", result1);
        } catch (final IOException e) {
            LOG.warn("Error calling Ubuntu proxy script!", e);
            throw new ProxyConfigurationError();
        }
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

    /**
     * This will refresh the proxy entries for things like new additions to
     * the whitelist.
     */
    public static void refresh() {
        if (isProxying()) {
            try {
                startProxying(true);
            } catch (final ProxyConfigurationError e) {
                LOG.error("Could not configure proxy!!", e);
            }
        }
    }
}
