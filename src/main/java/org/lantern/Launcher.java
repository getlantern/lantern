package org.lantern;

import java.io.File;
import java.io.IOException;
import java.lang.Thread.UncaughtExceptionHandler;
import java.util.Properties;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;
import org.apache.commons.cli.UnrecognizedOptionException;
import org.apache.log4j.Appender;
import org.apache.log4j.BasicConfigurator;
import org.apache.log4j.PropertyConfigurator;
import org.apache.log4j.spi.LoggingEvent;
import org.bns.getexceptional4j.GetExceptionalAppender;
import org.bns.getexceptional4j.GetExceptionalAppenderCallback;
import org.eclipse.swt.widgets.Display;
import org.json.simple.JSONObject;
import org.lantern.cookie.CookieFilter;
import org.lantern.cookie.CookieTracker;
import org.lantern.cookie.SetCookieObserver;
import org.littleshoot.proxy.DefaultHttpProxyServer;
import org.littleshoot.proxy.HttpFilter;
import org.littleshoot.proxy.HttpResponseFilters;
import org.littleshoot.proxy.KeyStoreManager;
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
                if (e.getMessage().contains("SWTError")) {
                    System.out.println(
                        "To run without a UI, run lantern with the --" + 
                        LanternConstants.OPTION_DISABLE_UI +
                        " command line argument");
                }
            }
        });
        
        final Options options = new Options();
        options.addOption(null, LanternConstants.OPTION_DISABLE_UI, false,
                          "run without a graphical user interface.");
        options.addOption(null, LanternConstants.OPTION_HELP, false,
                          "display command line help");
        final CommandLineParser parser = new PosixParser();
        final CommandLine cmd;
        try {
            cmd = parser.parse(options, args);
            if (cmd.getArgs().length > 0) {
                throw new UnrecognizedOptionException("Extra arguments were provided");
            }
        }
        catch (ParseException e) {
            printHelp(options, e.getMessage());
            return;
        }
        if (cmd.hasOption(LanternConstants.OPTION_HELP)) {
            printHelp(options, null);
            return;
        }
        
        if (cmd.hasOption(LanternConstants.OPTION_DISABLE_UI)) {
            LanternUtils.setUiEnabled(false);
        }
        else {
            LanternUtils.setUiEnabled(true);
        }
        
        
        LOG.info("Waiting for internet connection...");
        LanternUtils.waitForInternet();
        LOG.info("Got internet...");
        if (!LanternUtils.runWithUi()) {
            // We only run headless on Linux for now.
            LOG.info("Running Lantern with no display...");
            launchLantern();
            return;
        }
        Display.setAppName("Lantern");
        final Display display = LanternHub.display();
        
        // initialize properties, local ciphers etc on this thread 
        // before proceeding with more complicated stuffs.
        if (!LanternUtils.initProps()) {
            LOG.error("Unable to initialize local properties, exiting.");
            return;
        }
        
        if (!LanternUtils.isConfigured() || LanternUtils.newInstall()) {
            // Make sure the installer screens themselves don't run through a
            // defunct Lantern proxy that likely has just been uninstalled.
            LOG.info("Running install screen...newInstall: {}", 
                 LanternUtils.newInstall());
            Configurator.unproxy();
            final LanternBrowser browser = new LanternBrowser(false);
            browser.install();
            if (!display.isDisposed ()) {
                LOG.info("Browser completed...launching Lantern");
                launchLantern();
            }
        } else {
            launchLantern();
        }
        
        LanternHub.jettyLauncher().openBrowserWhenReady();
        //new StatsSimulator().start();
        
        // This is necessary to keep the tray/menu item up in the case
        // where we're not launching a browser.
        while (!display.isDisposed ()) {
            if (!display.readAndDispatch ()) display.sleep ();
        }
    }

    public static void launchLantern() {
        LanternHub.systemTray();
        final KeyStoreManager proxyKeyStore = LanternHub.getKeyStoreManager();
        final DefaultHttpProxyServer sslProxy = 
            new DefaultHttpProxyServer(LanternHub.randomSslPort(),
            new HttpResponseFilters() {
                @Override
                public HttpFilter getFilter(String arg0) {
                    return null;
                }
            }, null, proxyKeyStore, null);
        
        //final org.littleshoot.proxy.HttpProxyServer sslProxy = 
        //    new DefaultHttpProxyServer(LanternHub.randomSslPort());
        sslProxy.start(false, false);
         
        
        // We just use a fixed port for the plain-text proxy on localhost, as
        // there's no reason to randomize it since it's not public.
        // If testing two instances on the same machine, just change it on
        // one of them.
        
        // The reason this exists is complicated. It's for the case when the
        // offerer gets an incoming connection from the answerer, and then
        // only on the answerer side. The answerer "client" socket relays
        // its data to the local proxy.
        // See http://cdn.getlantern.org/IMAG0210.jpg
        final org.littleshoot.proxy.HttpProxyServer plainTextProxy = 
            new DefaultHttpProxyServer(
                LanternConstants.PLAINTEXT_LOCALHOST_PROXY_PORT);
        plainTextProxy.start(true, false);
        
        LOG.info("About to start Lantern server on port: "+
            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);
        
        final XmppHandler xmpp = LanternHub.xmppHandler();
        final CookieTracker cookieTracker = LanternHub.cookieTracker();
        final SetCookieObserver cookieObserver = new WhitelistSetCookieObserver(cookieTracker);
        final CookieFilter.Factory cookieFilterFactory = new DefaultCookieFilterFactory(cookieTracker);

        final HttpProxyServer server = 
            new LanternHttpProxyServer(
                LanternConstants.LANTERN_LOCALHOST_HTTP_PORT, 
                LanternConstants.LANTERN_LOCALHOST_HTTPS_PORT, 
                //null, sslRandomPort,
                proxyKeyStore, xmpp, cookieTracker, cookieFilterFactory);
        server.start();
    }

    
    private static void printHelp(Options options, String errorMessage) {
        if (errorMessage != null) {
            LOG.error(errorMessage);
            System.err.println(errorMessage);
        }
    
        final HelpFormatter formatter = new HelpFormatter();
        formatter.printHelp("lantern", options);
        return;
    }
    
    private static void configureLogger() {
        final String propsPath = "src/main/resources/log4j.properties";
        final File props = new File(propsPath);
        if (props.isFile()) {
            System.out.println("Running from main line");
            PropertyConfigurator.configure(propsPath);
        } else {
            System.out.println("Not on main line...");
            configureProductionLogger();
        }
    }
    
    private static void configureProductionLogger() {
        final File logDir = LanternUtils.logDir();
        final File logFile = new File(logDir, "java.log");
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
            final GetExceptionalAppenderCallback callback = 
                new GetExceptionalAppenderCallback() {

                    @Override
                    public boolean addData(final JSONObject json, 
                        final LoggingEvent le) {
                        json.put("version", LanternConstants.VERSION);
                        return true;
                    }
            };
            final Appender bugAppender = new GetExceptionalAppender(
               LanternConstants.GET_EXCEPTIONAL_API_KEY, callback);
            BasicConfigurator.configure(bugAppender);
        } catch (final IOException e) {
            System.out.println("Exception setting log4j props with file: "
                    + logFile);
            e.printStackTrace();
        }
    }
}
