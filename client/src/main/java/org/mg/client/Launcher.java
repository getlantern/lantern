package org.mg.client;

import java.lang.Thread.UncaughtExceptionHandler;

import org.apache.commons.lang.SystemUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


/**
 * Launches a new HTTP proxy.
 */
public class Launcher {

    private static final Logger LOG = LoggerFactory.getLogger(Launcher.class);
    
    private final static int DEFAULT_PORT = 8787;
    
    /**
     * Starts the proxy from the command line.
     * 
     * @param args Any command line arguments.
     */
    public static void main(final String... args) {
        Thread.setDefaultUncaughtExceptionHandler(new UncaughtExceptionHandler() {
            public void uncaughtException(final Thread t, final Throwable e) {
                LOG.error("Uncaught exception", e);
            }
        });
        configure();
        
        int port;
        if (args.length > 0) {
            final String arg = args[0];
            try {
                port = Integer.parseInt(arg);
            } catch (final NumberFormatException e) {
                port = DEFAULT_PORT;
            }
        } else {
            port = DEFAULT_PORT;
        }
        
        System.out.println("About to start server on port: "+port);
        final HttpProxyServer server = new DefaultHttpProxyServer(port);
        server.start();
    }

    private static void configure() {
        final SystemTray tray = new SystemTrayImpl();
        tray.createTray();
        
        configureRegistry();
    }

    private static void configureRegistry() {
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
        final String proxyEnableOriginal  = WindowsRegistry.read(key, pe);
        
        final String proxyServerUs = "127.0.0.1:"+DEFAULT_PORT;
        final String proxyEnableUs = "1";

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
        final Runnable runner = new Runnable() {
            public void run() {
                LOG.info("Resetting Windows registry settings");
                // On shutdown, we need to check if the user has modified the
                // registry since we originally set it. If they have, we want
                // to keep their setting. If not, we want to revert back to 
                // before MG started.
                final String proxyServer = WindowsRegistry.read(key, ps);
                final String proxyEnable = WindowsRegistry.read(key, pe);
                
                if (proxyServer.equals(proxyServerUs)) {
                    WindowsRegistry.writeREG_SZ(key, ps, proxyServerOriginal);
                }
                if (proxyEnable.equals(proxyEnableOriginal)) {
                    WindowsRegistry.writeREG_DWORD(key, pe, proxyEnableOriginal);
                }
            }
        };
        Runtime.getRuntime().addShutdownHook(new Thread (runner));
    }
}
