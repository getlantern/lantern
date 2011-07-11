package org.lantern;

import java.io.File;
import java.io.IOException;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.Collection;
import java.util.Collections;
import java.util.Enumeration;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.SystemUtils;
import org.littleshoot.util.CommonUtils;
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
    
    public static void configure() {
        if (configured) {
            LOG.error("Configure called twice?");
            return;
        }
        configured = true;
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
    

    public static void main(final String... args) throws SocketException {
        final Collection<String> services = mpm.getNetworkServices();
        System.out.println(services);
        
        Enumeration<NetworkInterface> nets = NetworkInterface.getNetworkInterfaces();
        
        for (NetworkInterface netIf : Collections.list(nets)) {
            System.out.printf("Display name: %s\n", netIf.getDisplayName());
            System.out.printf("Name: %s\n", netIf.getName());
            displaySubInterfaces(netIf);
            System.out.printf("\n");
        }
    }

    static void displaySubInterfaces(final NetworkInterface netIf) throws SocketException {
        Enumeration<NetworkInterface> subIfs = netIf.getSubInterfaces();
        
        for (NetworkInterface subIf : Collections.list(subIfs)) {
            System.out.printf("\tSub Interface Display name: %s\n", subIf.getDisplayName());
            System.out.printf("\tSub Interface Name: %s\n", subIf.getName());
        }
     }

    private static void configureOsxProxy() {
        final Collection<String> services = mpm.getNetworkServices();
        for (final String service : services) {
            LOG.info("Setting web proxy for {}", service);
            final String web = 
                "-setwebproxy '"+service.trim()+"' 127.0.0.1 " + 
                LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
            LOG.info("Running full command:\n{}", web);
            //CommonUtils.nativeCall(web);
            final String val1 = mpm.runNetworkSetup("-setwebproxy", service.trim(), 
                "127.0.0.1", String.valueOf(LanternConstants.LANTERN_LOCALHOST_HTTP_PORT));
            LOG.info("Got return val:\n"+val1);
            
            // Also set it for HTTPS!!
            LOG.info("Setting secure web proxy for {}", service);
            final String secure = 
                "-setsecurewebproxy '"+service.trim()+"' 127.0.0.1 " + 
                LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
            LOG.info("Running full command:\n{}", secure);
            
            final String val2 = mpm.runNetworkSetup("-setsecurewebproxy", service.trim(), 
                    "127.0.0.1", String.valueOf(LanternConstants.LANTERN_LOCALHOST_HTTP_PORT));
            //final String val2 = mpm.runNetworkSetup(secure);
            LOG.info("Got return val:\n"+val2);
            //CommonUtils.nativeCall(secure);
            
        }
        /*
        CommonUtils.nativeCall("networksetup -setwebproxy Airport 127.0.0.1 " + 
            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);
        CommonUtils.nativeCall("networksetup -setwebproxy Ethernet 127.0.0.1 " + 
            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);
        
        // Also set it for HTTPS!!
        CommonUtils.nativeCall("networksetup -setsecurewebproxy Airport 127.0.0.1 " + 
            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);
        CommonUtils.nativeCall("networksetup -setsecurewebproxy Ethernet 127.0.0.1 " + 
            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);
        */
        
        final Thread hook = new Thread(new Runnable() {
            @Override
            public void run() {
                for (final String service : services) {
                    
                    LOG.info("Unsetting web proxy "+service);
                    final String web = 
                        "-setwebproxystate '"+service.trim()+"' off";
                    LOG.info("Running full command:\n{}", web);
                    final String val1 = mpm.runNetworkSetup("-setwebproxystate", service.trim(), "off");
                    LOG.info("Got return val:\n"+val1);
                    //CommonUtils.nativeCall(web);
                    
                    LOG.info("Unsetting web proxy secure "+service);
                    final String secure = 
                        "-setsecurewebproxystate '"+service.trim()+"' off";
                    LOG.info("Running full command:\n{}", secure);
                    final String val2 = mpm.runNetworkSetup("-setsecurewebproxystate", service.trim(), "off");
                    LOG.info("Got return val:\n"+val2);
                    //CommonUtils.nativeCall(secure);
                }
                try {
                    Thread.sleep(400);
                } catch (final InterruptedException e) {
                    LOG.error("Interrupted?", e);
                }
                // Note that non-daemon hooks can exit prematurely with CTL-C,
                // but not if System.exit is used as it should be in deployed
                // versions.
                /*
                LOG.info("Unsetting web airport");
                CommonUtils.nativeCall("networksetup -setwebproxystate Airport off");
                LOG.info("Unsetting web ethernet");
                CommonUtils.nativeCall("networksetup -setwebproxystate Ethernet off");
                
                LOG.info("Unsetting secure airport");
                CommonUtils.nativeCall("networksetup -setsecurewebproxystate Airport off");
                LOG.info("Unsetting secure ethernet");
                CommonUtils.nativeCall("networksetup -setsecurewebproxystate Ethernet off");
                */
            }
            
        }, "Unset-Web-Proxy-OSX");
        Runtime.getRuntime().addShutdownHook(hook);
    }

    private static void configureWindowsProxy() {
        if (!SystemUtils.IS_OS_WINDOWS) {
            LOG.info("Not running on Windows");
            return;
        }
        final String key = 
            "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\" +
            "Internet Settings";
        
        final String ps = "ProxyServer";
        final String pe = "ProxyEnable";
        
        // We first want to read the start values so we can return the
        // registry to the original state when we shut down.
        final String proxyServerOriginal = WindowsRegistry.read(key, ps);
        final String proxyEnableOriginal = WindowsRegistry.read(key, pe);
        
        final String proxyServerUs = "127.0.0.1:"+
            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
        final String proxyEnableUs = "1";

        LOG.info("Setting registry to use MG as a proxy...");
        final int enableResult = 
            WindowsRegistry.writeREG_SZ(key, ps, proxyServerUs);
        final int serverResult = 
            WindowsRegistry.writeREG_DWORD(key, pe, proxyEnableUs);
        
        if (enableResult != 0) {
            LOG.error("Error enabling the proxy server? Result: "+enableResult);
        }
    
        if (serverResult != 0) {
            LOG.error("Error setting proxy server? Result: "+serverResult);
        }
        copyFirefoxConfig();
        
        final Runnable runner = new Runnable() {
            @Override
            public void run() {
                LOG.info("Resetting Windows registry settings to " +
                    "original values.");
                
                // On shutdown, we need to check if the user has modified the
                // registry since we originally set it. If they have, we want
                // to keep their setting. If not, we want to revert back to 
                // before MG started.
                final String proxyServer = WindowsRegistry.read(key, ps);
                final String proxyEnable = WindowsRegistry.read(key, pe);
                
                //LOG.info("Proxy enable original: '{}'", proxyEnableUs);
                //LOG.info("Proxy enable now: '{}'", proxyEnable);
                
                if (proxyEnable.equals(proxyEnableUs)) {
                    LOG.info("Setting proxy enable back to: {}", 
                        proxyEnableOriginal);
                    WindowsRegistry.writeREG_DWORD(key, pe,proxyEnableOriginal);
                    LOG.info("Successfully reset proxy enable");
                }
                
                if (proxyServer.equals(proxyServerUs)) {
                    LOG.info("Setting proxy server back to: {}", 
                        proxyServerOriginal);
                    WindowsRegistry.writeREG_SZ(key, ps, proxyServerOriginal);
                    LOG.info("Successfully reset proxy server");
                }
                LOG.info("Done resetting the Windows registry");
            }
        };
        
        // We don't make this a daemon thread because we want to make sure it
        // executes before shutdown.
        Runtime.getRuntime().addShutdownHook(new Thread (runner));
    }

    /**
     * Installs the FireFox config file on startup. Public for testing.
     */
    private static void copyFirefoxConfig() {
        final File ff = 
            new File(System.getenv("ProgramFiles"), "Mozilla Firefox");
        final File pref = new File(new File(ff, "defaults"), "pref");
        LOG.info("Prefs dir: {}", pref);
        if (!pref.isDirectory()) {
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
