package org.mg.client;

import java.io.File;
import java.io.IOException;
import java.lang.Thread.UncaughtExceptionHandler;
import java.util.HashMap;
import java.util.Properties;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.SystemUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.apache.log4j.PropertyConfigurator;
import org.lastbamboo.common.util.CommonUtils;
import org.littleshoot.proxy.DefaultHttpProxyServer;
import org.littleshoot.proxy.HttpFilter;
import org.littleshoot.proxy.KeyStoreManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


/**
 * Launches a new Lantern HTTP proxy.
 */
public class Launcher {

    private static Logger LOG;
    
    private final static int DEFAULT_PORT = 8787;
    
    /**
     * Starts the proxy from the command line.
     * 
     * @param args Any command line arguments.
     */
    public static void main(final String... args) {
        configureLogger();
        LOG = LoggerFactory.getLogger(Launcher.class);
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
        
        final KeyStoreManager proxyKeyStore = 
            new LanternKeyStoreManager(true);
        final int sslRandomPort = randomPort();
        LOG.info("Running straight HTTP proxy on port: "+sslRandomPort);
        final org.littleshoot.proxy.HttpProxyServer sslProxy = 
            new DefaultHttpProxyServer(sslRandomPort,
                new HashMap<String, HttpFilter>(), null, proxyKeyStore, null);
        sslProxy.start(false, false);
        
        // We just use a fixed port for the plain-text proxy on localhost, as
        // there's no reason to randomize it since it's not public.
        // If testing two instances on the same machine, just change it on
        // one of them.
        final int plainTextRandomPort = 7777;
        final org.littleshoot.proxy.HttpProxyServer plainTextProxy = 
            new DefaultHttpProxyServer(plainTextRandomPort);
        plainTextProxy.start(true, false);
        
        LOG.info("About to start Lantern server on port: "+port);
        final HttpProxyServer server = 
            new LanternHttpProxyServer(port, proxyKeyStore, sslRandomPort,
                plainTextRandomPort);
        server.start();
    }
    
    private static void configureLogger() {
        final File logDirParent;
        final File logDir;
        if (SystemUtils.IS_OS_WINDOWS) {
            logDirParent = CommonUtils.getDataDir();
            logDir = new File(logDirParent, "logs");
        } else if (SystemUtils.IS_OS_MAC_OSX) {
            logDirParent = new File("/Library/Logs/");
            logDir = new File(logDirParent, "Lantern");
        } else {
            logDirParent = new File(SystemUtils.getUserHome(), ".lantern");
            logDir = new File(logDirParent, "logs");
        }

        if (!logDirParent.isDirectory()) {
            if (!logDirParent.mkdirs()) {
                System.out.println("Could not create parent at: "
                        + logDirParent);
                return;
            }
        }
        if (!logDir.isDirectory()) {
            if (!logDir.mkdirs()) {
                System.out.println("Could not create dir at: " + logDir);
                return;
            }
        }

        final String propsPath = "src/main/resources/log4j.properties";
        final File props = new File(propsPath);
        if (props.isFile()) {
            System.out.println("Running from main line");
            PropertyConfigurator.configure(propsPath);
        } else {
            System.out.println("Not on main line...");
            final File logFile = new File(logDir, "java.log");
            setLoggerProps(logFile);
        }
    }
    
    private static void setLoggerProps(final File logFile) {
        final Properties props = new Properties();
        try {
            final String logPath = logFile.getCanonicalPath();
            props.put("log4j.appender.RollingTextFile.File", logPath);
            props.put("log4j.rootLogger", "warn, RollingTextFile");
            props.put("log4j.appender.RollingTextFile",
                    "org.apache.log4j.RollingFileAppender");
            props.put("log4j.appender.RollingTextFile.MaxFileSize", "1MB");
            props.put("log4j.appender.RollingTextFile.MaxBackupIndex", "1");
            props.put("log4j.appender.RollingTextFile.layout",
                    "org.apache.log4j.PatternLayout");
            props.put(
                    "log4j.appender.RollingTextFile.layout.ConversionPattern",
                    "%-6r %d{ISO8601} %-5p [%t] %c{2}.%M (%F:%L) - %m%n");

            // This throws and swallows a FileNotFoundException, but it
            // doesn't matter. Just weird.
            PropertyConfigurator.configure(props);
            System.out.println("Set logger file to: " + logPath);
        } catch (final IOException e) {
            System.out.println("Exception setting log4j props with file: "
                    + logFile);
            e.printStackTrace();
        }
    }

    private static int randomPort() {
        return 1024 + (RandomUtils.nextInt() % 60000);
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
        final String proxyEnableOriginal = WindowsRegistry.read(key, pe);
        
        final String proxyServerUs = "127.0.0.1:"+DEFAULT_PORT;
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
            }
        };
        
        // We don't make this a daemon thread because we want to make sure it
        // executes before shutdown.
        Runtime.getRuntime().addShutdownHook(new Thread (runner));
    }

    /**
     * Installs the FireFox config file on startup. Public for testing.
     */
    public static void copyFirefoxConfig() {
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
}
