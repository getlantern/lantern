package org.lantern;

import com.google.common.eventbus.Subscribe;

import java.io.File;
import java.io.IOException;
import java.lang.Thread.UncaughtExceptionHandler;
import java.net.URI;
import java.net.URISyntaxException;
import java.security.GeneralSecurityException;
import java.util.Arrays;
import java.util.Collection;
import java.util.Properties;

import org.lantern.privacy.InvalidKeyException;
import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;
import org.apache.commons.cli.UnrecognizedOptionException;
import org.apache.commons.io.FileUtils;
import org.apache.log4j.Appender;
import org.apache.log4j.BasicConfigurator;
import org.apache.log4j.PropertyConfigurator;
import org.apache.log4j.spi.LoggingEvent;
import org.eclipse.swt.SWTError;
import org.eclipse.swt.widgets.Display;
import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.json.simple.JSONObject;
import org.lantern.cookie.CookieFilter;
import org.lantern.cookie.CookieTracker;
import org.lantern.cookie.SetCookieObserver;
import org.lantern.exceptional4j.ExceptionalAppender;
import org.lantern.exceptional4j.ExceptionalAppenderCallback;
import org.littleshoot.proxy.DefaultHttpProxyServer;
import org.littleshoot.proxy.HttpFilter;
import org.littleshoot.proxy.HttpRequestFilter;
import org.littleshoot.proxy.HttpResponseFilters;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.proxy.PublicIpsOnlyRequestFilter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


/**
 * Launches a new Lantern HTTP proxy.
 */
public class Launcher {

    private static Logger LOG;
    private static boolean lanternStarted = false;
    
    
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
                handleError(e, false);
            }
        });
        
        try {
            launch(args);
        } catch (final Throwable t) {
            handleError(t, true);
        }
    }

    private static void launch(final String... args) {
        LOG.info("Starting Lantern...");

        // first apply any command line settings
        final Options options = new Options();
        options.addOption(null, LanternConstants.OPTION_DISABLE_UI, false,
                          "run without a graphical user interface.");
        
        options.addOption(null, LanternConstants.OPTION_API_PORT, true,
            "the port to run the API server on.");
        options.addOption(null, LanternConstants.OPTION_PUBLIC_API, false,
            "make the API server publicly accessible on non-localhost.");
        options.addOption(null, LanternConstants.OPTION_HELP, false,
                          "display command line help");
        options.addOption(null, LanternConstants.OPTION_LAUNCHD, false,
            "running from launchd - not normally called from command line");
        options.addOption(null, LanternConstants.OPTION_DISABLE_KEYCHAIN, false, 
            "disable use of system keychain and ask for local password");
        final CommandLineParser parser = new PosixParser();
        final CommandLine cmd;
        try {
            cmd = parser.parse(options, args);
            if (cmd.getArgs().length > 0) {
                throw new UnrecognizedOptionException("Extra arguments were provided");
            }
        }
        catch (ParseException e) {
            printHelp(options, e.getMessage()+" args: "+Arrays.asList(args));
            return;
        }
        if (cmd.hasOption(LanternConstants.OPTION_HELP)) {
            printHelp(options, null);
            return;
        }
        
        if (cmd.hasOption(LanternConstants.OPTION_DISABLE_UI)) {
            LOG.info("Disabling UI");
            LanternHub.settings().setUiEnabled(false);
        }
        else {
            LanternHub.settings().setUiEnabled(true);
        }
        
        /* option to disable use of keychains in local privacy */
        if (cmd.hasOption(LanternConstants.OPTION_DISABLE_KEYCHAIN)) {
            LOG.info("Disabling use of system keychains");
            LanternHub.settings().setKeychainEnabled(false);
        }
        else {
            LanternHub.settings().setKeychainEnabled(true);
        }
        
        
        if (cmd.hasOption(LanternConstants.OPTION_PUBLIC_API)) {
            LanternHub.settings().setBindToLocalhost(false);
        }
        if (cmd.hasOption(LanternConstants.OPTION_API_PORT)) {
            final String portStr = 
                cmd.getOptionValue(LanternConstants.OPTION_API_PORT);
            LOG.info("Using command-line port: "+portStr);
            final int port = Integer.parseInt(portStr);
            LanternHub.settings().setApiPort(port);
        } else {
            LOG.info("Using random port...");
            LanternHub.settings().setApiPort(LanternUtils.randomPort());
        }
        LOG.info("Running API on port: {}", LanternHub.settings().getApiPort());

        if (cmd.hasOption(LanternConstants.OPTION_LAUNCHD)) {
            LOG.info("Running from launchd or launchd set on command line");
            LanternHub.settings().setLaunchd(true);
        } else {
            LanternHub.settings().setLaunchd(false);
        }
        
        final Display display;
        if (LanternHub.settings().isUiEnabled()) {
            // We initialize this super early in case there are any errors 
            // during startup we have to display to the user.
            Display.setAppName("Lantern");
            display = LanternHub.display();
            // Also, We need the system tray to listen for events early on.
            LanternHub.systemTray().createTray();
        }
        else {
            display = null;
        }
        
        loadSettings();
        
        if (LanternUtils.hasNetworkConnection()) {
            LOG.info("Got internet...");
            launchWithOrWithoutUi();
        } else {
            // If we're running on startup, it's quite likely we just haven't
            // connected to the internet yet. Let's wait for an internet
            // connection and then start Lantern.
            if (LanternHub.settings().isLaunchd() || !LanternHub.settings().isUiEnabled()) {
                LOG.info("Waiting for internet connection...");
                LanternUtils.waitForInternet();
                launchWithOrWithoutUi();
            }
            // If setup is complete and we're not running on startup, open
            // the dashboard.
            else if (LanternHub.settings().isInitialSetupComplete()) {
                LanternHub.jettyLauncher().openBrowserWhenReady();
                // Wait for an internet connection before starting the XMPP
                // connection.
                LOG.info("Waiting for internet connection...");
                LanternUtils.waitForInternet();
                launchWithOrWithoutUi();
            } else {
                // If we haven't configured Lantern and don't have an internet
                // connection, the problem is that we can't verify the user's
                // user name and password when they try to login, so we just
                // let them know we can't start Lantern until they have a 
                // connection.
                // TODO: i18n
                final String msg = 
                    "We're sorry, but you cannot configure Lantern without " +
                    "an active connection to the internet. Please try again " +
                    "when you have an internet connection.";
                LanternHub.dashboard().showMessage("No Internet", msg);
                System.exit(0);
            }
        }

        
        // This is necessary to keep the tray/menu item up in the case
        // where we're not launching a browser.
        if (display != null) {
            while (!display.isDisposed ()) {
                if (!display.readAndDispatch ()) display.sleep ();
            }
        }
    }

    private static void loadSettings() {
        LanternHub.resetSettings(true);
        if (LanternHub.settings().getSettings().getState() == SettingsState.State.CORRUPTED) {
            try {
                // current behavior is automatic reset of all local data / ciphers
                // immediately.  This behavior could be deferred until later or handled
                // in some other way.
                LOG.warn("Destroying corrupt settings...");
                LanternHub.destructiveFullReset();
            }
            catch (IOException e) {
                LOG.error("Failed to reset corrupt settings: {}", e);
                System.exit(1);
            }
            // still corrupt?
            if (LanternHub.settings().getSettings().getState() == SettingsState.State.CORRUPTED) {
                LOG.error("Failed to reset corrupt settings.");
                System.exit(1);
            }
            else {
                LOG.info("Settings have been reset.");
            }
        }
        
        // if there is no UI and the settings are locked, we need to grab the password on 
        // the command line or else quit.
        if (!LanternHub.settings().isUiEnabled() && 
            LanternHub.settings().getSettings().getState() == SettingsState.State.LOCKED) {
            if (!askToUnlockSettingsCLI()) {
                LOG.error("Unable to unlock settings.");
                System.exit(1);
            }
        }
        
        LOG.info("Settings state is {}", LanternHub.settings().getSettings().getState());
    }
    
    private static boolean askToUnlockSettingsCLI() {
        if (!LanternHub.localCipherProvider().requiresAdditionalUserInput()) {
            LOG.info("Local cipher does not require a password.");
            return true;
        }
        while(true) {
            char [] pw = null; 
            try {
                pw = readSettingsPasswordCLI();
                return unlockSettingsWithPassword(pw);
            }
            catch (final InvalidKeyException e) {
                System.out.println("Password was incorrect, try again."); // XXX i18n
            }
            catch (final GeneralSecurityException e) {
                LOG.error("Error unlocking settings: {}", e);
            }
            catch (final IOException e) {
                LOG.error("Erorr unlocking settings: {}", e);
            }
            finally {
                LanternUtils.zeroFill(pw);
            }
        }
    }
    
    private static char [] readSettingsPasswordCLI() throws IOException {
        if (LanternHub.settings().isLocalPasswordInitialized() == false) {
            while (true) {
                // XXX i18n
                System.out.print("Please enter a password to protect your local data:");
                System.out.flush();
                final char [] pw1 = LanternUtils.readPasswordCLI();
                if (pw1.length == 0) {
                    System.out.println("password cannot be blank, please try again.");
                    System.out.flush();
                    continue;
                }
                System.out.print("Please enter password again:");
                System.out.flush();
                final char [] pw2 = LanternUtils.readPasswordCLI();
                if (Arrays.equals(pw1, pw2)) {
                    // zero out pw2
                    LanternUtils.zeroFill(pw2);
                    return pw1;
                }
                else {
                    LanternUtils.zeroFill(pw1);
                    LanternUtils.zeroFill(pw2);
                    System.out.println("passwords did not match, please try again.");
                    System.out.flush();
                }
            }
        }
        else {
            System.out.print("Please enter your lantern password:");
            System.out.flush();
            return LanternUtils.readPasswordCLI();
        }
    }
    
    
    private static boolean unlockSettingsWithPassword(final char [] password)
        throws GeneralSecurityException, IOException {
        final boolean init = !LanternHub.settings().isLocalPasswordInitialized();
        LanternHub.localCipherProvider().feedUserInput(password, init);
        LanternHub.resetSettings(true);
        final SettingsState.State ss = LanternHub.settings().getSettings().getState();
        if (ss != SettingsState.State.SET) {
            LOG.error("Settings did not unlock, state is {}", ss);
            return false;
        }
        return true;
    }
    
    private static void launchWithOrWithoutUi() {
        if (!LanternHub.settings().isUiEnabled()) {
            // We only run headless on Linux for now.
            LOG.info("Running Lantern with no display...");
            launchLantern();
            LanternHub.jettyLauncher();
            return;
        }

        LOG.debug("Is launchd: {}", LanternHub.settings().isLaunchd());
        launchLantern();
        if (!LanternHub.settings().isLaunchd() || 
            !LanternHub.settings().isInitialSetupComplete()) {
            LanternHub.jettyLauncher().openBrowserWhenReady();
        }
    }

    public static void launchLantern() {
        LOG.debug("Launching Lantern...");
        final KeyStoreManager proxyKeyStore = LanternHub.getKeyStoreManager();
        
        final HttpRequestFilter publicOnlyRequestFilter = 
            new PublicIpsOnlyRequestFilter();
        
        // Note that just passing in the keystore manager triggers this to 
        // become an SSL proxy server.
        final StatsTrackingDefaultHttpProxyServer sslProxy =
            new StatsTrackingDefaultHttpProxyServer(LanternHub.randomSslPort(),
            new HttpResponseFilters() {
                @Override
                public HttpFilter getFilter(String arg0) {
                    return null;
                }
            }, null, proxyKeyStore, publicOnlyRequestFilter);
        LOG.debug("SSL port is {}", LanternHub.randomSslPort());
        //final org.littleshoot.proxy.HttpProxyServer sslProxy = 
        //    new DefaultHttpProxyServer(LanternHub.randomSslPort());
        sslProxy.start(false, false);
         
        // The reason this exists is complicated. It's for the case when the
        // offerer gets an incoming connection from the answerer, and then
        // only on the answerer side. The answerer "client" socket relays
        // its data to the local proxy.
        // See http://cdn.getlantern.org/IMAG0210.jpg
        final org.littleshoot.proxy.HttpProxyServer plainTextProxy = 
            new DefaultHttpProxyServer(
                LanternConstants.PLAINTEXT_LOCALHOST_PROXY_PORT,
                publicOnlyRequestFilter);
        plainTextProxy.start(true, false);
        
        LOG.info("About to start Lantern server on port: "+
            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);


        /* delegate all calls to the current hub cookie tracker */
        final CookieTracker hubTracker = new CookieTracker() {

            @Override
            public void setCookies(Collection<Cookie> cookies, HttpRequest context) {
                LanternHub.cookieTracker().setCookies(cookies, context);
            }

            @Override
            public boolean wouldSendCookie(final Cookie cookie, final URI toRequestUri) {
                return LanternHub.cookieTracker().wouldSendCookie(cookie, toRequestUri);
            }

            @Override
            public boolean wouldSendCookie(final Cookie cookie, final URI toRequestUri, final boolean requireValueMatch) {
                return LanternHub.cookieTracker().wouldSendCookie(cookie, toRequestUri, requireValueMatch);
            }

            @Override
            public CookieFilter asOutboundCookieFilter(final HttpRequest request, final boolean requireValueMatch) throws URISyntaxException {
                return LanternHub.cookieTracker().asOutboundCookieFilter(request, requireValueMatch);
            }
        };

        final SetCookieObserver cookieObserver = new WhitelistSetCookieObserver(hubTracker);
        final CookieFilter.Factory cookieFilterFactory = new DefaultCookieFilterFactory(hubTracker);
        final HttpProxyServer server = 
            new LanternHttpProxyServer(
                LanternConstants.LANTERN_LOCALHOST_HTTP_PORT, 
                //null, sslRandomPort,
                proxyKeyStore, cookieObserver, cookieFilterFactory);
        server.start();
        
        // 
        AutoConnector ac = new AutoConnector(); 
        
        lanternStarted = true;
    }

    /**
     * the autoconnector tries to auto-connect the 
     * first time that it observes that the settings 
     * have reached the SET state.
     */
    private static class AutoConnector {
        
        private boolean done = false;
        
        public AutoConnector() {
            checkAutoConnect();
            if (!done) {
                LanternHub.register(this);
            }
        }
        
        @Subscribe
        public void onStateChange(final SettingsStateEvent sse) {
            checkAutoConnect();
        }
        
        private void checkAutoConnect() {
            if (done) {
                return;
            }
            if (LanternHub.settings().getSettings().getState() != SettingsState.State.SET) {
                LOG.info("not testing auto-connect, settings are not ready.");
                return;
            }
            
            // only test once.
            done = true;
            
            LOG.info("Settings loaded, testing auto-connect behavior");
            // This won't connect in the case where the user hasn't entered 
            // their user name and password and the user is running with a UI.
            // Otherwise, it will connect.
            XmppHandler xmpp = LanternHub.xmppHandler();
            if (LanternHub.settings().isConnectOnLaunch() &&
                (LanternUtils.isConfigured() || !LanternHub.settings().isUiEnabled())) {
                try {
                    xmpp.connect();
                } catch (final IOException e) {
                    LOG.info("Could not login", e);
                }
            } else {
                LOG.info("Not auto-logging in with settings:\n{}",
                    LanternHub.settings());
            }

            try {
                LanternHub.configurator().copyFireFoxExtension();
            } catch (final IOException e) {
                LOG.error("Could not copy extension", e);
            }
        }
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
            final ExceptionalAppenderCallback callback = 
                new ExceptionalAppenderCallback() {

                    @Override
                    public boolean addData(final JSONObject json, 
                        final LoggingEvent le) {
                        json.put("version", LanternConstants.VERSION);
                        return true;
                    }
            };
            final Appender bugAppender = new ExceptionalAppender(
               LanternConstants.GET_EXCEPTIONAL_API_KEY, callback);
            BasicConfigurator.configure(bugAppender);
        } catch (final IOException e) {
            System.out.println("Exception setting log4j props with file: "
                    + logFile);
            e.printStackTrace();
        }
    }
    
    private static void handleError(final Throwable t, final boolean exit) {
        LOG.error("Uncaught exception: "+t.getMessage(), t);
        if (t instanceof SWTError || t.getMessage().contains("SWTError")) {
            System.out.println(
                "To run without a UI, run lantern with the --" + 
                LanternConstants.OPTION_DISABLE_UI +
                " command line argument");
        } 
        else if (!lanternStarted && LanternHub.settings().isUiEnabled()) {
            LOG.info("Showing error to user...");
            LanternHub.dashboard().showMessage("Startup Error",
               "We're sorry, but there was an error starting Lantern " +
               "described as '"+t.getMessage()+"'.");
        }
        if (exit) {
            LOG.info("Exiting Lantern");
            System.exit(1);
        }
    }
}
