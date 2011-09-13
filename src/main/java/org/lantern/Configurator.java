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
    private volatile static boolean configured = false;
    
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
        
        if (CensoredUtils.isCensored() || CensoredUtils.isForceCensored()) {
            LOG.info("Auto-configuring proxy...");
            
            // We only want to configure the proxy if the user is in censored mode.
            if (SystemUtils.IS_OS_MAC_OSX) {
                configureOsxProxy();
            } else if (SystemUtils.IS_OS_WINDOWS) {
                configureWindowsProxy();
                // The firewall config is actually handled in a bat file from the
                // installer.
                //configureWindowsFirewall();
            }
        } else {
            LOG.info("Not auto-configuring proxy in an uncensored country");
        }
    }
    
    private static void configureOsxProxy() {
        configureOsxProxyPacFile();
        configureOsxScript();
        // Note that non-daemon hooks can exit prematurely with CTL-C,
        // but not if System.exit is used as it should be in deployed
        // versions.
        final Thread hook = new Thread(new Runnable() {
            @Override
            public void run() {
                LOG.info("Unproxying...");
                unproxyOsx();
            }
        }, "Unset-Web-Proxy-OSX");
        Runtime.getRuntime().addShutdownHook(hook);
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


    private static void configureWindowsProxy() {
        if (!SystemUtils.IS_OS_WINDOWS) {
            LOG.info("Not running on Windows");
            return;
        }
        
        // We first want to read the start values so we can return the
        // registry to the original state when we shut down.
        final String proxyServerOriginal = 
            WindowsRegistry.read(WINDOWS_REGISTRY_PROXY_KEY, ps);
        final String proxyEnableOriginal = 
            WindowsRegistry.read(WINDOWS_REGISTRY_PROXY_KEY, pe);
        
        final String proxyServerUs = "127.0.0.1:"+
            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
        final String proxyEnableUs = "1";

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
        
        final Runnable runner = new Runnable() {
            @Override
            public void run() {
                unproxyWindows(proxyServerOriginal, proxyEnableOriginal);
            }
        };
        
        // We don't make this a daemon thread because we want to make sure it
        // executes before shutdown.
        Runtime.getRuntime().addShutdownHook(new Thread (runner));
    }

    public static void unproxy() {
        if (SystemUtils.IS_OS_WINDOWS) {
            // We first want to read the start values so we can return the
            // registry to the original state when we shut down.
            final String proxyServerOriginal = 
                WindowsRegistry.read(WINDOWS_REGISTRY_PROXY_KEY, ps);
            if (proxyServerOriginal.equals(LANTERN_PROXY_ADDRESS)) {
                unproxyWindows(proxyServerOriginal, "0");
            }
        } else if (SystemUtils.IS_OS_MAC_OSX) {
            unproxyOsx();
        } else {
            LOG.warn("We don't yet support proxy configuration on other OSes");
        }
    }
    
    protected static void unproxyWindows(final String proxyServerOriginal, 
        final String proxyEnableOriginal) {
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
            LOG.info("Setting proxy enable back to: {}", 
                proxyEnableOriginal);
            WindowsRegistry.writeREG_DWORD(WINDOWS_REGISTRY_PROXY_KEY, pe, 
                proxyEnableOriginal);
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
