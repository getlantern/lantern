package org.lantern;

import java.io.File;
import java.io.IOException;
import java.lang.Thread.UncaughtExceptionHandler;
import java.util.HashMap;
import java.util.Properties;

import org.apache.commons.lang.SystemUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.apache.log4j.PropertyConfigurator;
import org.eclipse.swt.widgets.Display;
import org.littleshoot.proxy.DefaultHttpProxyServer;
import org.littleshoot.proxy.HttpFilter;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.util.CommonUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


/**
 * Launches a new Lantern HTTP proxy.
 */
public class Launcher {

    private static Logger LOG;
    
    /**
     * Starts the proxy from the command line.
     * 
     * @param args Any command line arguments.
     */
    public static void main(final String... args) {
        configureLogger();
        LOG = LoggerFactory.getLogger(Launcher.class);
        Thread.setDefaultUncaughtExceptionHandler(new UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(final Thread t, final Throwable e) {
                LOG.error("Uncaught exception", e);
            }
        });
        Display.setAppName("Lantern");
        final Display display = new Display();
        //final Shell shell = new Shell(display);
        final SystemTray tray = new SystemTrayImpl(display);
        tray.createTray();
        
        if (!LanternUtils.isConfigured()) {
            launchBrowser(display);
            LOG.info("Browser completed");

        } else {
            launchLantern();
        }
        
        // This is necessary to keep the tray/menu item up in the case
        // where we're not launching a browser.
        while (!display.isDisposed ()) {
            if (!display.readAndDispatch ()) display.sleep ();
        }
    }

    public static void launchLantern() {
        final KeyStoreManager proxyKeyStore = 
            new LanternKeyStoreManager(true);
        final int sslRandomPort = randomPort();
        LOG.info("Running straight HTTP proxy on port: "+sslRandomPort);
        /*
        final org.littleshoot.proxy.HttpProxyServer sslProxy = 
            new DefaultHttpProxyServer(sslRandomPort,
                new HashMap<String, HttpFilter>(), null, proxyKeyStore, null);
         */ 
        
        final org.littleshoot.proxy.HttpProxyServer sslProxy = 
            new DefaultHttpProxyServer(sslRandomPort,
                new HashMap<String, HttpFilter>(), null, null, null);
        sslProxy.start(false, false);
         
        
        // We just use a fixed port for the plain-text proxy on localhost, as
        // there's no reason to randomize it since it's not public.
        // If testing two instances on the same machine, just change it on
        // one of them.
        final org.littleshoot.proxy.HttpProxyServer plainTextProxy = 
            new DefaultHttpProxyServer(
                LanternConstants.PLAINTEXT_LOCALHOST_PROXY_PORT);
        plainTextProxy.start(true, false);
        
        LOG.info("About to start Lantern server on port: "+
            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);
        final HttpProxyServer server = 
            new LanternHttpProxyServer(
                LanternConstants.LANTERN_LOCALHOST_HTTP_PORT, 
                LanternConstants.LANTERN_LOCALHOST_HTTPS_PORT, 
                //null, sslRandomPort,
                proxyKeyStore, sslRandomPort,
                LanternConstants.PLAINTEXT_LOCALHOST_PROXY_PORT);
        server.start();
        final Configurator config = new Configurator();
        config.configure();
    }

    private static void launchBrowser(final Display display) {
        final LanternBrowser browser = new LanternBrowser(display);
        browser.install();
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
}
