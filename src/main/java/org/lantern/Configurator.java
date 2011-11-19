package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.Collection;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.SystemUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Configures Lantern. This can be either on the first run of the application
 * or through the user changing his or her configurations in the configuration
 * screen.
 */
public class Configurator {
    
    private static final Logger LOG = 
        LoggerFactory.getLogger(Configurator.class);
    
    /**
     * File external processes can use to determine if Lantern is currently
     * proxying traffic. Useful for things like the FireFox extensions.
     */
    private static final File LANTERN_PROXYING_FILE =
        new File(LanternUtils.configDir(), "lanternProxying");
    
    private volatile static boolean configured = false;
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
        
        try {
            copyFireFoxExtension();
        } catch (final IOException e) {
            LOG.error("Could not copy extension", e);
        }
    }
    
    private static final File ACTIVE_PAC = 
        new File(LanternUtils.configDir(), "proxy.pac");
    
    public static void configure() {
        if (configured) {
            LOG.error("Configure called twice?");
            return;
        }
        configured = true;
        reconfigure();
    }
    

    /**
     * Copies our FireFox extension to the appropriate place.
     * 
     * @return The {@link File} for the final destination directory of the
     * extension.
     * @throws IOException If there's an error copying the extension.
     */
    public static File copyFireFoxExtension() throws IOException {
        LOG.info("Copying file extension");
        final File dir = getExtensionDir();
        if (!dir.isDirectory()) {
            LOG.info("Making FireFox extension directory...");
            // NOTE: This likely means the user does not have FireFox. We copy
            // the extension here anyway in case the user ever installs 
            // FireFox in the future.
            if (!dir.mkdirs()) {
                LOG.error("Could not create directory!"+dir);
            }
        }
        final File ffDir = new File("firefox/lantern@getlantern.org");
        if (!ffDir.isDirectory()) {
            LOG.error("No extension directory found at {}", ffDir);
            throw new IOException("Could not find extension?");
        }
        FileUtils.copyDirectoryToDirectory(ffDir, dir);
        LOG.info("Copied FireFox extension from {} to {}", ffDir, dir);
        return new File(dir, ffDir.getName());
    }

    private static File getExtensionDir() {
        final File userHome = SystemUtils.getUserHome();
        if (SystemUtils.IS_OS_WINDOWS) {
            final File ffDir = new File(System.getenv("APPDATA"), "Mozilla");
            return new File(ffDir, "Extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}");
        } else if (SystemUtils.IS_OS_MAC_OSX) {
            return new File(userHome, 
                "Library/Application Support/Mozilla/Extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}");
        } else {
            return new File(userHome, "Mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}");
        }
    }

    public static void reconfigure() {
        if (!LanternUtils.propsFile().isFile()) {
            System.out.println("PLEASE ENTER YOUR GOOGLE ACCOUNT DATA IN " + 
                LanternUtils.propsFile() + " in the following form:" +
                "\ngoogle.user=your_name@gmail.com\ngoogle.pwd=your_password");
            return;
        }
        final File git = new File(".git");
        if (git.isDirectory() && !CensoredUtils.isForceCensored()) {
            LOG.info("Running from repository...not auto-configuring proxy.");
            return;
        }
        
        if (LanternUtils.shouldProxy()) {
            LOG.info("Auto-configuring proxy...");
            
            startProxying();
            
            final Thread hook = new Thread(new Runnable() {
                @Override
                public void run() {
                    LOG.info("Unproxying...");
                    stopProxying();
                }
            }, "Unset-Web-Proxy-Thread");
            Runtime.getRuntime().addShutdownHook(hook);
        } else {
            LOG.info("Not auto-configuring proxy in an uncensored country");
        }
    }
    
    public static void startProxying() {
        if (LanternUtils.shouldProxy()) {
            try {
                if (!LANTERN_PROXYING_FILE.createNewFile()) {
                    LOG.error("Could not create proxy file?");
                }
            } catch (IOException e) {
                LOG.error("Could not create proxy file?", e);
            }
            LOG.info("Starting to proxy Lantern");
            if (SystemUtils.IS_OS_MAC_OSX) {
                proxyOsx();
            } else if (SystemUtils.IS_OS_WINDOWS) {
                proxyWindows();
            } else if (SystemUtils.IS_OS_LINUX) {
                // TODO: proxyLinux();
            }
        } else {
            LOG.info("Not configuring proxy in an uncensored country");
        }
    }

    public static void stopProxying() {
        if (LanternUtils.shouldProxy()) {
            LOG.info("Unproxying Lantern");
            LANTERN_PROXYING_FILE.delete();
            if (SystemUtils.IS_OS_MAC_OSX) {
                unproxyOsx();
            } else if (SystemUtils.IS_OS_WINDOWS) {
                unproxyWindows();
            } else if (SystemUtils.IS_OS_LINUX) {
                // TODO: unproxyLinux();
            }
        } else {
            LOG.info("Not configuring proxy in an uncensored country");
        }
    }
    
    private static void proxyOsx() {
        configureOsxProxyPacFile();
        configureOsxScript();
    }

    private static void configureOsxScript() {
        final String result = mpm.runScript(getScriptPath(), "on");
        LOG.info("Result of script is: {}", result);
    }
    
    private static String getScriptPath() {
        final String name = "configureNetworkServices.bash";
        final File script = new File(name);
        if (!script.isFile()) {
            final String msg = "No file: "+script.getAbsolutePath()+"\nfrom "+
                new File(".").getAbsolutePath();
            LOG.error(msg);
            throw new IllegalStateException(msg);
        }
        final String path = script.getAbsolutePath();
        LOG.info("Returning script path: {}", path);
        return path;
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


    private static void configureOsxProxyNetworkSetup() {
        final Collection<String> services = mpm.getNetworkServices();
        for (final String service : services) {
            LOG.info("Setting web proxy for {}", service);
            final String val1 = mpm.runNetworkSetup("-setwebproxy", service.trim(), 
                "127.0.0.1", String.valueOf(LanternConstants.LANTERN_LOCALHOST_HTTP_PORT));
            LOG.info("Got return val:\n"+val1);
            
            // Also set it for HTTPS!!
            LOG.info("Setting secure web proxy for {}", service);
            final String val2 = mpm.runNetworkSetup("-setsecurewebproxy", service.trim(), 
                "127.0.0.1", String.valueOf(LanternConstants.LANTERN_LOCALHOST_HTTP_PORT));
            LOG.info("Got return val:\n"+val2);
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
    }


    public static void unproxy() {
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
        
        LOG.info("Done resetting the Windows registry");
    }

    private static void unproxyOsx() {
        unproxyOsxPacFile();
        unproxyOsxScript();
    }
    
    private static void unproxyOsxScript() {
        final String result = mpm.runScript(getScriptPath(), "off");
        LOG.info("Result of script is: {}", result);
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
    
    private static void unproxyOsxNetworkServices() {
        final Collection<String> services = mpm.getNetworkServices();
        for (final String service : services) {
            
            LOG.info("Unsetting web proxy "+service);
            final String val1 = mpm.runNetworkSetup(
                "-setwebproxystate", service.trim(), "off");
            LOG.info("Got return val:\n"+val1);
            
            LOG.info("Unsetting web proxy secure "+service);
            final String val2 = mpm.runNetworkSetup(
                "-setsecurewebproxystate", service.trim(), "off");
            LOG.info("Got return val:\n"+val2);
        }
    }

    public static boolean configured() {
        return configured;
    }

    /**
     * Installs the FireFox config file on startup. 
     */
    private static void copyFirefoxConfig() {
        final File ff;
        if (SystemUtils.IS_OS_WINDOWS) {
            ff = new File(System.getenv("ProgramFiles"), "Mozilla Firefox");
        } else if (SystemUtils.IS_OS_MAC_OSX) {
            ff = new File("/Applications/Firefox.app//Contents/MacOS");
        } else {
            LOG.info("Not sure where to copy FireFox config on Linux");
            return;
        }
        final File pref = new File(new File(ff, "defaults"), "pref");
        LOG.info("Prefs dir: {}", pref);
        if (ff.isDirectory() && !pref.isDirectory()) {
            LOG.error("No directory at: {}", pref);
        }
        final File config = new File("all-bravenewsoftware.js");
        
        if (!config.isFile()) {
            LOG.error("NO CONFIG FILE AT {}", config);
        }
        else {
            try {
                FileUtils.copyFileToDirectory(config, pref);
                final File installedConfig = new File(pref, config.getName());
                installedConfig.deleteOnExit();
            } catch (final IOException e) {
                LOG.error("Could not copy config file?", e);
            }
        }
    }

    /*
     * This is done in the installer.
    private void configureWindowsFirewall() {
        final boolean oldNetSh;
        if (SystemUtils.IS_OS_WINDOWS_2000 ||
            SystemUtils.IS_OS_WINDOWS_XP) {
            oldNetSh = true;
        }
        else {
            oldNetSh = false;
        }

        if (oldNetSh) {
            final String[] commands = {
                "netsh", "firewall", "add", "allowedprogram", 
                "\""+SystemUtils.getUserDir()+"/Lantern.exe\"", "\"Lantern\"", 
                "ENABLE"
            };
            CommonUtils.nativeCall(commands);
        } else {
            final String[] commands = {
                "netsh", "advfirewall", "firewall", "add", "rule", 
                "name=\"Lantern\"", "dir=in", "action=allow", 
                "program=\""+SystemUtils.getUserDir()+"/Lantern.exe\"", 
                "enable=yes", "profile=any"
            };
            CommonUtils.nativeCall(commands);
        }
    }
    */
}
