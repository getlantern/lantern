package org.lantern;

import java.io.File;
import java.io.IOException;

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
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    public void configure() {
        
        // We only want to configure the proxy if the user is in censored mode.
        if (SystemUtils.IS_OS_MAC_OSX) {
            configureOsxProxy();
        } else if (SystemUtils.IS_OS_WINDOWS) {
            configureWindowsProxy();
            // The firewall config is actually handled in a bat file from the
            // installer.
            //configureWindowsFirewall();
        }
    }

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

    private void configureOsxProxy() {
        CommonUtils.nativeCall("networksetup -setwebproxy Airport 127.0.0.1 " + 
            LanternConstants.LANTERN_LOCALHOST_PORT);
        CommonUtils.nativeCall("networksetup -setwebproxy Ethernet 127.0.0.1 " + 
            LanternConstants.LANTERN_LOCALHOST_PORT);
        
        final Thread hook = new Thread(new Runnable() {
            public void run() {
                CommonUtils.nativeCall("networksetup -setwebproxystate Airport off");
                CommonUtils.nativeCall("networksetup -setwebproxystate Ethernet off");
            }
            
        }, "Unset-Web-Proxy-OSX");
        Runtime.getRuntime().addShutdownHook(hook);
    }

    private void configureWindowsProxy() {
        if (!SystemUtils.IS_OS_WINDOWS) {
            log.info("Not running on Windows");
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
            LanternConstants.LANTERN_LOCALHOST_PORT;
        final String proxyEnableUs = "1";

        log.info("Setting registry to use MG as a proxy...");
        final int enableResult = 
            WindowsRegistry.writeREG_SZ(key, ps, proxyServerUs);
        final int serverResult = 
            WindowsRegistry.writeREG_DWORD(key, pe, proxyEnableUs);
        
        if (enableResult != 0) {
            log.error("Error enabling the proxy server? Result: "+enableResult);
        }
    
        if (serverResult != 0) {
            log.error("Error setting proxy server? Result: "+serverResult);
        }
        copyFirefoxConfig();
        
        final Runnable runner = new Runnable() {
            public void run() {
                log.info("Resetting Windows registry settings to " +
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
                    log.info("Setting proxy enable back to: {}", 
                        proxyEnableOriginal);
                    WindowsRegistry.writeREG_DWORD(key, pe,proxyEnableOriginal);
                    log.info("Successfully reset proxy enable");
                }
                
                if (proxyServer.equals(proxyServerUs)) {
                    log.info("Setting proxy server back to: {}", 
                        proxyServerOriginal);
                    WindowsRegistry.writeREG_SZ(key, ps, proxyServerOriginal);
                    log.info("Successfully reset proxy server");
                }
                log.info("Done resetting the Windows registry");
            }
        };
        
        // We don't make this a daemon thread because we want to make sure it
        // executes before shutdown.
        Runtime.getRuntime().addShutdownHook(new Thread (runner));
    }

    /**
     * Installs the FireFox config file on startup. Public for testing.
     */
    private void copyFirefoxConfig() {
        final File ff = 
            new File(System.getenv("ProgramFiles"), "Mozilla Firefox");
        final File pref = new File(new File(ff, "defaults"), "pref");
        log.info("Prefs dir: {}", pref);
        if (!pref.isDirectory()) {
            log.error("No directory at: {}", pref);
        }
        final File config = new File("all-bravenewsoftware.js");
        
        if (!config.isFile()) {
            log.error("NO CONFIG FILE AT {}", config);
        }
        else {
            try {
                FileUtils.copyFileToDirectory(config, pref);
                final File installedConfig = new File(pref, config.getName());
                installedConfig.deleteOnExit();
            } catch (final IOException e) {
                log.error("Could not copy config file?", e);
            }
        }
    }

}
