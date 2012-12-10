package org.lantern;

import java.io.File;
import java.io.IOException;
import java.lang.Thread.UncaughtExceptionHandler;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.security.GeneralSecurityException;
import java.security.Security;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashSet;
import java.util.Properties;

import javax.security.auth.login.CredentialException;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;
import org.apache.commons.cli.UnrecognizedOptionException;
import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.SystemUtils;
import org.apache.log4j.Appender;
import org.apache.log4j.BasicConfigurator;
import org.apache.log4j.PropertyConfigurator;
import org.apache.log4j.spi.LoggingEvent;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.eclipse.swt.SWTError;
import org.eclipse.swt.widgets.Display;
import org.json.simple.JSONObject;
import org.lantern.event.Events;
import org.lantern.exceptional4j.ExceptionalAppender;
import org.lantern.exceptional4j.ExceptionalAppenderCallback;
import org.lantern.http.JettyLauncher;
import org.lantern.privacy.InvalidKeyException;
import org.lantern.privacy.LocalCipherProvider;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;
import org.lantern.state.ModelUtils;
import org.lantern.state.Settings;
import org.lantern.state.Settings.Mode;
import org.lantern.state.StaticSettings;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.lastbamboo.common.stun.client.PublicIpAddress;
import org.lastbamboo.common.stun.client.StunServerRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Guice;
import com.google.inject.Injector;


/**
 * Launches a new Lantern HTTP proxy.
 */
public class Launcher {

    private static Logger LOG;
    private static boolean lanternStarted = false;
    private static LanternHttpProxyServer localProxy;
    private static PlainTestRelayHttpProxyServer plainTextAnsererRelayProxy;
    private static JettyLauncher jettyLauncher;
    private static XmppHandler xmpp;
    private static BrowserService browserService;
    
    private static SslHttpProxyServer sslProxy;
    
    private static LocalCipherProvider localCipherProvider;
    
    private static MessageService messageService;
    private static Injector injector;
    private static SystemTray systemTray;
    private static Model model;
    private static ModelUtils modelUtils;
    private static Settings set;
    private static Censored censored;
    
    /**
     * Starts the proxy from the command line.
     * 
     * @param args Any command line arguments.
     */
    public static void main(final String... args) {
        Thread.currentThread().setName("Lantern-Main-Thread");
        //Connection.DEBUG_ENABLED = true;
        configureLogger();
        LOG = LoggerFactory.getLogger(Launcher.class);
        Thread.setDefaultUncaughtExceptionHandler(new UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(final Thread t, final Throwable e) {
                handleError(e, false);
            }
        });
        
        final Runnable runner = new Runnable() {

            @Override
            public void run() {
                try {
                    launch(args);
                } catch (final Throwable t) {
                    handleError(t, true);
                }
            }
        };
        final Thread main = new Thread(runner, "Lantern-Launch-Thread");
        //main.start();
        runner.run();
        if (SystemUtils.IS_OS_LINUX) {
            synchronized (runner) {
                try {
                    runner.wait();
                } catch (final InterruptedException e) {
                    LOG.info("Interrupted", e);
                }
            }
        }
    }

    private static void launch(final String... args) {
        LOG.info("Starting Lantern...");
        configureCipherSuites();

        // first apply any command line settings
        final Options options = buildOptions();

        final CommandLineParser parser = new PosixParser();
        final CommandLine cmd;
        try {
            cmd = parser.parse(options, args);
            if (cmd.getArgs().length > 0) {
                throw new UnrecognizedOptionException("Extra arguments were provided");
            }
        }
        catch (final ParseException e) {
            printHelp(options, e.getMessage()+" args: "+Arrays.asList(args));
            return;
        }
        
        if (cmd.hasOption(OPTION_HELP)) {
            printHelp(options, null);
            return;
        } else if (cmd.hasOption(OPTION_VERSION)) {
            printVersion();
            return;
        }

        injector = Guice.createInjector(new LanternModule());
        model = instance(Model.class);
        set = model.getSettings();
        
        // We parse this one separately because we need this value right away.
        if (cmd.hasOption(OPTION_DISABLE_UI)) {
            LOG.info("Disabling UI");
            set.setUiEnabled(false);
        }
        else {
            set.setUiEnabled(true);
        }
        
        censored = instance(Censored.class);
        threadPublicIpLookup();
        
        LOG.debug("Creating display...");
        final Display display;
        if (set.isUiEnabled()) {
            // We initialize this super early in case there are any errors 
            // during startup we have to display to the user.
            Display.setAppName("Lantern");
            //display = injector.getInstance(Display.class);;
            display = DisplayWrapper.getDisplay();
            // Also, We need the system tray to listen for events early on.
            //LanternHub.systemTray().createTray();
            
        }
        else {
            display = null;
        }
        
        messageService = instance(MessageService.class);
        xmpp = instance(DefaultXmppHandler.class);
        jettyLauncher = instance(JettyLauncher.class);
        browserService = instance(BrowserService.class);
        sslProxy = instance(SslHttpProxyServer.class);
        localCipherProvider = instance(LocalCipherProvider.class);
        plainTextAnsererRelayProxy = instance(PlainTestRelayHttpProxyServer.class);
        systemTray = instance(SystemTray.class);
        modelUtils = instance(ModelUtils.class);
        localProxy = instance(LanternHttpProxyServer.class);
        
        if (set.isUiEnabled()) {
            LOG.debug("Starting system tray..");
            try {
                systemTray.start();
            } catch (final Exception e) {
                LOG.error("Error starting tray?", e);
            }
            LOG.debug("Started system tray..");
        }
        
        LOG.debug("Processing command line options...");
        processCommandLineOptions(cmd);
        LOG.debug("Processed command line options...");
        
        shutdownable(ModelIo.class);
        
        jettyLauncher.start();
        xmpp.start();
        sslProxy.start(false, false);
        localProxy.start();
        plainTextAnsererRelayProxy.start(true, false);
        
        gnomeAutoStart();
        
        // Use our stored STUN servers if available.
        final Collection<String> stunServers = set.getStunServers();
        if (stunServers != null && !stunServers.isEmpty()) {
            LOG.info("Using stored STUN servers: {}", stunServers);
            StunServerRepository.setStunServers(toSocketAddresses(stunServers));
        }
        if (LanternUtils.hasNetworkConnection()) {
            LOG.info("Got internet...");
            launchWithOrWithoutUi();
        } else {
            // If we're running on startup, it's quite likely we just haven't
            // connected to the internet yet. Let's wait for an internet
            // connection and then start Lantern.
            if (model.isLaunchd() || !set.isUiEnabled()) {
                LOG.info("Waiting for internet connection...");
                LanternUtils.waitForInternet();
                launchWithOrWithoutUi();
            }
            // If setup is complete and we're not running on startup, open
            // the dashboard.
            else if (model.isSetupComplete()) {
                browserService.openBrowserWhenPortReady();
                //jettyLauncher.openBrowserWhenReady();
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
                messageService.showMessage("No Internet", msg);
                System.exit(0);
                
                // The new-ui wants to allow the user to configure this later?
                //launchWithOrWithoutUi();
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
    

    /**
     * We thread this because otherwise looking up our public IP address 
     * over the network can delay the creation of settings altogether. That's
     * problematic if the UI is waiting on them, for example.
     */
    private static void threadPublicIpLookup() {
        if (LanternConstants.ON_APP_ENGINE) {
            return;
        }
        final Thread thread = new Thread(new Runnable() {
            @Override
            public void run() {
                // This performs the public IP lookup so by the time we set
                // GET versus GIVE mode we already know the IP and don't have
                // to wait.
                
                // We get the address here to set it in Connectivity.
                final InetAddress ip = 
                    new PublicIpAddress().getPublicIpAddress();
                if (ip == null) {
                    LOG.info("No IP -- possibly no internet connection");
                    return;
                }
                model.getConnectivity().setIp(ip.getHostAddress());
                
                // The IP is cached at this point.
                
                try {
                    final Country count = censored.country();
                    model.getLocation().setCountry(count.getCode());
                } catch (final IOException e) {
                    LOG.error("Could not get country", e);
                }
                // If the mode isn't set in the model, set the default.
                if (set.getMode() == null || set.getMode() == Mode.none) {
                    if (censored.isCensored()) {
                        set.setMode(Mode.get);
                        set.setGetMode(true);
                    } else {
                        set.setMode(Mode.give);
                        set.setGetMode(false);
                    }
                }
            }
            
        }, "Public-IP-Lookup-Thread");
        thread.setDaemon(true);
        thread.start();
    }

    private static <T> void shutdownable(final Class<T> clazz) {
        instance(clazz);
    }

    private static <T> T instance(final Class<T> clazz) {
        final T inst = injector.getInstance(clazz);
        if (Shutdownable.class.isAssignableFrom(clazz)) {
            addShutdownHook((Shutdownable) inst);
        }
        return inst;
    }

    private static void addShutdownHook(final Shutdownable service) {
        LOG.info("Adding shutdown hook for {}", service);
        // TODO: Add these all to a single list of things to do on shutdown.
        final Thread serviceHook = new Thread(new Runnable() {
            @Override
            public void run() {
                service.stop();
            }
        }, "ShutdownHook-For-Service-"+service.getClass().getSimpleName());
        Runtime.getRuntime().addShutdownHook(serviceHook);
    }
    
    private static void gnomeAutoStart() {
        // Before setup we should just do the default, which is to run on
        // startup. The user can configure this differently at any point 
        // hereafter.
        if (SystemUtils.IS_OS_LINUX && 
            !LanternConstants.GNOME_AUTOSTART.isFile()) {
            final File lanternDesktop;
            final File candidate1 = 
                new File(LanternConstants.GNOME_AUTOSTART.getName());
            final File candidate2 = 
                new File("install/linux", LanternConstants.GNOME_AUTOSTART.getName());
            if (candidate1.isFile()) {
                lanternDesktop = candidate1;
            } else if (candidate2.isFile()){
                lanternDesktop = candidate2;
            } else {
                LOG.error("Could not find lantern.desktop file");
                return;
            }
            try {
                final File parent = LanternConstants.GNOME_AUTOSTART.getParentFile();
                if (!parent.isDirectory()) {
                    if (!parent.mkdirs()) {
                        LOG.error("Could not make dir for gnome autostart: "+parent);
                        return;
                    }
                }
                FileUtils.copyFileToDirectory(lanternDesktop, parent);
                
                LOG.info("Copied {} to {}", lanternDesktop, parent);
            } catch (final IOException e) {
                LOG.error("Could not configure gnome autostart", e);
            }
        }
    }

    private static void configureCipherSuites() {
        Security.addProvider(new BouncyCastleProvider());
        if (!LanternUtils.isUnlimitedKeyStrength()) {
            if (!SystemUtils.IS_OS_WINDOWS_VISTA) {
                LOG.error("No policy files on non-Vista machine!!");
            }
            LOG.info("Reverting to weaker ciphers on Vista");
            IceConfig.setCipherSuites(new String[] {
                //"TLS_DHE_RSA_WITH_AES_128_CBC_SHA"
                "TLS_ECDHE_RSA_WITH_RC4_128_SHA"
            });
        } else {
            // Note the following just sets what cipher suite the server 
            // side selects. DHE is for perfect forward secrecy.
            
            // We include 128 because we never have enough permissions to 
            // copy the unlimited strength policy files on Vista, so we have 
            // to revert back to 128.
            IceConfig.setCipherSuites(new String[] {
                //"TLS_DHE_RSA_WITH_AES_256_CBC_SHA",
                //"TLS_DHE_RSA_WITH_AES_128_CBC_SHA"
                //"TLS_RSA_WITH_RC4_128_SHA"
                "TLS_ECDHE_RSA_WITH_RC4_128_SHA"
            });
        }
    }
    
    
    private static Collection<InetSocketAddress> toSocketAddresses(
        final Collection<String> stunServers) {
        final Collection<InetSocketAddress> isas = 
            new HashSet<InetSocketAddress>();
        for (final String server : stunServers) {
            final String host = StringUtils.substringBefore(server, ":");
            final String port = StringUtils.substringAfter(server, ":");
            isas.add(new InetSocketAddress(host, Integer.parseInt(port)));
        }
        return isas;
    }

    private static boolean parseOptionDefaultTrue(final CommandLine cmd, 
        final String option) {
        if (cmd.hasOption(option)) {
            LOG.info("Found option: "+option);
            return false;
        }
        
        // DEFAULTS TO TRUE!!
        return true;
    }
    
    private static boolean parseOptionDefaultFalse(final CommandLine cmd, 
        final String option) {
        if (cmd.hasOption(option)) {
            LOG.info("Found option: "+option);
            return false;
        }
        
        return false;
    }
    
    private static void loadLocalPasswordFile(final String pwFilename) {
        //final LocalCipherProvider lcp = localCipherProvider;
        if (!localCipherProvider.requiresAdditionalUserInput()) {
            LOG.error("Settings do not require a password to unlock.");
            System.exit(1);
        }

        if (StringUtils.isBlank(pwFilename)) {
            LOG.error("No filename specified to --{}", OPTION_PASSWORD_FILE);
            System.exit(1);
        }
        final File pwFile = new File(pwFilename);
        if (!(pwFile.exists() && pwFile.canRead())) {
            LOG.error("Unable to read password from {}", pwFilename);
            System.exit(1);
        }

        LOG.info("Reading local password from file \"{}\"", pwFilename);
        try {
            final String pw = FileUtils.readLines(pwFile, "US-ASCII").get(0);
            final boolean init = !localCipherProvider.isInitialized();
            localCipherProvider.feedUserInput(pw.toCharArray(), init);
        }
        catch (final IndexOutOfBoundsException e) {
            LOG.error("Password in file \"{}\" was incorrect", pwFilename);
            System.exit(1);
        }
        catch (final InvalidKeyException e) {
            LOG.error("Password in file \"{}\" was incorrect", pwFilename);
            System.exit(1);
        }
        catch (final GeneralSecurityException e) {
            LOG.error("Failed to initialize using password in file \"{}\": {}", pwFilename, e);
            System.exit(1);
        }
        catch (final IOException e) {
            LOG.error("Failed to initialize using password in file \"{}\": {}", pwFilename, e);
            System.exit(1);
        }
    }

    private static void launchWithOrWithoutUi() {
        if (!set.isUiEnabled()) {
            // We only run headless on Linux for now.
            LOG.info("Running Lantern with no display...");
            launchLantern();
            //LanternHub.jettyLauncher();
            return;
        }

        LOG.debug("Is launchd: {}", model.isLaunchd());
        launchLantern();
        /*
        if (!model.isLaunchd() || 
            !model.isSetupComplete()) {
            //!LanternHub.settings().isInitialSetupComplete()) {
            browserService.openBrowserWhenPortReady();
        }
        */
    }

    public static void launchLantern() {
        LOG.debug("Launching Lantern...");
        if (set.isUiEnabled()) {
            browserService.openBrowserWhenPortReady();
        }
        
        new AutoConnector(); 
        
        lanternStarted = true;
    }

    /**
     * The autoconnector tries to auto-connect the first time that it observes 
     * that the settings have reached the SET state.
     */
    private static class AutoConnector {
        
        private boolean done = false;
        
        private AutoConnector() {
            checkAutoConnect();
            if (!done) {
                Events.register(this);
            }
        }
        
        private void checkAutoConnect() {
            LOG.info("Checking auto-connect...");
            if (done) {
                return;
            }
            
            // only test once.
            done = true;
            
            LOG.info("Settings loaded, testing auto-connect behavior");
            // This won't connect in the case where the user hasn't entered 
            // their user name and password and the user is running with a UI.
            // Otherwise, it will connect.
            if (model.getSettings().isAutoStart() && //LanternHub.settings().isConnectOnLaunch() &&
                (modelUtils.isConfigured() || !set.isUiEnabled())) {
                final Runnable runner = new Runnable() {
                    @Override
                    public void run() {
                        try {
                            xmpp.connect();
                            //LanternHub.xmppHandler().connect();
                        } catch (final IOException e) {
                            LOG.info("Could not login", e);
                        } catch (final CredentialException e) {
                            LOG.info("Bad credentials");
                        } catch (final NotInClosedBetaException e) {
                            LOG.warn("Not in closed beta!!");
                        }
                    }
                };
                final Thread t = 
                    new Thread(runner, "Auto-Connect-From-Settings-Ready");
                t.setDaemon(true);
                t.start();
            } else {
                LOG.info("Not auto-logging in with model:\n{}", model);
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
    }
    
    private static void printVersion() {
        System.out.println("Lantern version "+LanternConstants.VERSION);
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
        final File logDir = LanternConstants.LOG_DIR;
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
                        if (!set.isAutoReport()) {
                            // Don't report anything if the user doesn't have
                            // it turned on.
                            return false;
                        }
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
        final String msg = msg(t);
        LOG.error("Uncaught exception: "+msg, t);
        if (t instanceof SWTError || msg.contains("SWTError")) {
            System.out.println(
                "To run without a UI, run lantern with the --" + 
                OPTION_DISABLE_UI +
                " command line argument");
        } 
        else if (t instanceof UnsatisfiedLinkError && 
            msg.contains("Cannot load 32-bit SWT libraries on 64-bit JVM")) {
            messageService.showMessage("Architecture Error",
                "We're sorry, but it appears you're running 32-bit Lantern on a 64-bit JVM.");
        }
        else if (!lanternStarted && set.isUiEnabled()) {
            LOG.info("Showing error to user...");
            messageService.showMessage("Startup Error",
               "We're sorry, but there was an error starting Lantern " +
               "described as '"+msg+"'.");
        }
        if (exit) {
            LOG.info("Exiting Lantern");
            System.exit(1);
        }
    }

    private static String msg(final Throwable t) {
        final String msg = t.getMessage();
        if (msg == null) {
            return "";
        } 
        return msg;
    }


    // the following are command line options 
    private static final String OPTION_DISABLE_UI = "disable-ui";
    private static final String OPTION_HELP = "help";
    private static final String OPTION_LAUNCHD = "launchd";
    private static final String OPTION_PUBLIC_API = "public-api";
    private static final String OPTION_API_PORT = "api-port";
    private static final String OPTION_SERVER_PORT = "server-port";
    private static final String OPTION_DISABLE_KEYCHAIN = "disable-keychain";
    private static final String OPTION_PASSWORD_FILE = "password-file";
    private static final String OPTION_TRUSTED_PEERS = "disable-trusted-peers";
    private static final String OPTION_ANON_PEERS ="disable-anon-peers";
    private static final String OPTION_LAE = "disable-lae";
    private static final String OPTION_CENTRAL = "disable-central";
    private static final String OPTION_UDP = "disable-udp";
    private static final String OPTION_TCP = "disable-tcp";
    private static final String OPTION_USER = "user";
    private static final String OPTION_PASS = "pass";
    private static final String OPTION_GET = "force-get";
    private static final String OPTION_GIVE = "force-give";
    private static final String OPTION_NO_CACHE = "no-cache";
    private static final String OPTION_VERSION = "version";
    private static final String OPTION_NEW_UI = "new-ui";
    public static final String OPTION_OAUTH2_CLIENT_SECRETS_FILE = "oauth2-client-secrets-file";
    public static final String OPTION_OAUTH2_USER_CREDENTIALS_FILE = "oauth2-user-credentials-file";

    private static Options buildOptions() {
        final Options options = new Options();
        options.addOption(null, OPTION_DISABLE_UI, false,
            "run without a graphical user interface.");
        options.addOption(null, OPTION_API_PORT, true,
            "the port to run the API server on.");
        options.addOption(null, OPTION_SERVER_PORT, true,
            "the port to run the give mode proxy server on.");
        options.addOption(null, OPTION_PUBLIC_API, false,
            "make the API server publicly accessible on non-localhost.");
        options.addOption(null, OPTION_HELP, false,
            "display command line help");
        options.addOption(null, OPTION_LAUNCHD, false,
            "running from launchd - not normally called from command line");
        options.addOption(null, OPTION_DISABLE_KEYCHAIN, false, 
            "disable use of system keychain and ask for local password");
        options.addOption(null, OPTION_PASSWORD_FILE, true, 
            "read local password from the file specified");
        options.addOption(null, OPTION_TRUSTED_PEERS, false,
            "disable use of trusted peer-to-peer connections for proxies.");
        options.addOption(null, OPTION_ANON_PEERS, false,
            "disable use of anonymous peer-to-peer connections for proxies.");
        options.addOption(null, OPTION_LAE, false,
            "disable use of app engine proxies.");
        options.addOption(null, OPTION_CENTRAL, false,
            "disable use of centralized proxies.");
        options.addOption(null, OPTION_UDP, false,
            "disable UDP for peer-to-peer connections.");
        options.addOption(null, OPTION_TCP, false,
            "disable TCP for peer-to-peer connections.");
        options.addOption(null, OPTION_USER, true,
            "Google user name -- WARNING INSECURE - ONLY USE THIS FOR TESTING!");
        options.addOption(null, OPTION_PASS, true,
            "Google password -- WARNING INSECURE - ONLY USE THIS FOR TESTING!");
        options.addOption(null, OPTION_GET, false, "Force running in get mode");
        options.addOption(null, OPTION_GIVE, false, "Force running in give mode");
        options.addOption(null, OPTION_NO_CACHE, false,
            "Don't allow caching of static files in the dashboard");
        options.addOption(null, OPTION_VERSION, false, 
            "Print the Lantern version");
        options.addOption(null, OPTION_NEW_UI, false,
            "Use the new UI under the 'ui' directory");
        options.addOption(null, OPTION_OAUTH2_CLIENT_SECRETS_FILE, true,
            "read Google OAuth2 client secrets from the file specified");
        options.addOption(null, OPTION_OAUTH2_USER_CREDENTIALS_FILE, true,
            "read Google OAuth2 user credentials from the file specified");
        return options;
    }
    

    private static void processCommandLineOptions(final CommandLine cmd) {

        final String secOpt = OPTION_OAUTH2_CLIENT_SECRETS_FILE;
        if (cmd.hasOption(secOpt)) {
            modelUtils.loadOAuth2ClientSecretsFile(
                cmd.getOptionValue(secOpt));
        }

        final String credOpt = OPTION_OAUTH2_USER_CREDENTIALS_FILE;
        if (cmd.hasOption(credOpt)) {
            modelUtils.loadOAuth2UserCredentialsFile(
                cmd.getOptionValue(credOpt));
        }
        
        //final Settings set = LanternHub.settings();
        
        set.setUseTrustedPeers(parseOptionDefaultTrue(cmd, OPTION_TRUSTED_PEERS));
        set.setUseAnonymousPeers(parseOptionDefaultTrue(cmd, OPTION_ANON_PEERS));
        set.setUseLaeProxies(parseOptionDefaultTrue(cmd, OPTION_LAE));
        set.setUseCentralProxies(parseOptionDefaultTrue(cmd, OPTION_CENTRAL));
        
        IceConfig.setTcp(parseOptionDefaultTrue(cmd, OPTION_TCP));
        IceConfig.setUdp(parseOptionDefaultTrue(cmd, OPTION_UDP));
        
        /*
        if (cmd.hasOption(OPTION_USER)) {
            set.setUserId(cmd.getOptionValue(OPTION_USER));
        }
        if (cmd.hasOption(OPTION_PASS)) {
            set.(cmd.getOptionValue(OPTION_PASS));
        }
        */
        
        /* option to disable use of keychains in local privacy */
        if (cmd.hasOption(OPTION_DISABLE_KEYCHAIN)) {
            LOG.info("Disabling use of system keychains");
            set.setKeychainEnabled(false);
        }
        else {
            set.setKeychainEnabled(true);
        }
        
        if (cmd.hasOption(OPTION_PASSWORD_FILE)) {
            loadLocalPasswordFile(cmd.getOptionValue(OPTION_PASSWORD_FILE));
        }

        if (cmd.hasOption(OPTION_PUBLIC_API)) {
            set.setBindToLocalhost(false);
        }
        if (cmd.hasOption(OPTION_API_PORT)) {
            final String apiPortStr =
                cmd.getOptionValue(OPTION_API_PORT);
            LOG.info("Using command-line port: "+ apiPortStr);
            final int apiPort = Integer.parseInt(apiPortStr);
            StaticSettings.setApiPort(apiPort);
        } else {
            LOG.info("Using random port...");
        }
        LOG.info("Running API on port: {}", StaticSettings.getApiPort());

        if (cmd.hasOption(OPTION_SERVER_PORT)) {
            final String serverPortStr =
                cmd.getOptionValue(OPTION_SERVER_PORT);
            LOG.info("Using command-line proxy port: "+serverPortStr);
            final int serverPort = Integer.parseInt(serverPortStr);
            set.setServerPort(serverPort);
        } else {
            LOG.info("Using random give mode proxy port...");
            set.setServerPort(LanternUtils.randomPort());
        }
        LOG.info("Running give mode proxy on port: {}", set.getServerPort());
        
        if (cmd.hasOption(OPTION_LAUNCHD)) {
            LOG.info("Running from launchd or launchd set on command line");
            model.setLaunchd(true);
        } else {
            model.setLaunchd(false);
        }
        
        if (cmd.hasOption(OPTION_GIVE)) {
            model.getSettings().setGetMode(false);
        } else if (cmd.hasOption(OPTION_GET)) {
            model.getSettings().setGetMode(true);
        }
        
        model.setCache(!LanternUtils.isDevMode());
        if (cmd.hasOption(OPTION_NO_CACHE)) {
            model.setCache(false);
        }
    }
}
