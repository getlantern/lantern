package org.lantern;

import java.io.File;
import java.io.IOException;
import java.lang.Thread.UncaughtExceptionHandler;
import java.net.InetSocketAddress;
import java.security.GeneralSecurityException;
import java.security.Security;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashSet;
import java.util.Properties;
import java.util.Timer;

import javax.security.auth.login.CredentialException;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.cli.PosixParser;
import org.apache.commons.cli.UnrecognizedOptionException;
import org.apache.commons.io.FileUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.SystemUtils;
import org.apache.http.HttpResponse;
import org.apache.http.ProtocolVersion;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.impl.DefaultHttpResponseFactory;
import org.apache.log4j.Appender;
import org.apache.log4j.BasicConfigurator;
import org.apache.log4j.Level;
import org.apache.log4j.PropertyConfigurator;
import org.apache.log4j.spi.LoggingEvent;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.eclipse.swt.SWTError;
import org.eclipse.swt.widgets.Display;
import org.json.simple.JSONObject;
import org.lantern.event.Events;
import org.lantern.event.MessageEvent;
import org.lantern.event.RefreshTokenEvent;
import org.lantern.exceptional4j.ExceptionalAppender;
import org.lantern.exceptional4j.ExceptionalAppenderCallback;
import org.lantern.exceptional4j.HttpStrategy;
import org.lantern.http.GeoIp;
import org.lantern.http.JettyLauncher;
import org.lantern.monitoring.StatsReporter;
import org.lantern.privacy.InvalidKeyException;
import org.lantern.privacy.LocalCipherProvider;
import org.lantern.proxy.GetModeProxy;
import org.lantern.proxy.GiveModeProxy;
import org.lantern.state.InternalState;
import org.lantern.state.Modal;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;
import org.lantern.state.ModelUtils;
import org.lantern.state.Settings;
import org.lantern.state.StaticSettings;
import org.lantern.state.SyncService;
import org.lantern.util.HttpClientFactory;
import org.lantern.util.Stopwatch;
import org.lantern.util.StopwatchManager;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.UpnpService;
import org.lastbamboo.common.stun.client.StunServerRepository;
import org.littleshoot.util.CommonUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.barchart.udt.ResourceUDT;
import com.google.common.eventbus.Subscribe;
import com.google.inject.Guice;
import com.google.inject.Injector;

/**
 * Launches a new Lantern HTTP proxy.
 */
public class Launcher {
    static {
        // this sets the system property necessary for barchart udt to extract
        // to the correct place
        System.setProperty(ResourceUDT.PROPERTY_LIBRARY_EXTRACT_LOCATION, 
                CommonUtils.getLittleShootDir().getAbsolutePath());
        
        //System.setProperty("javax.net.debug", "ssl");
        
        // Set the following for debugging XMPP connections.
        //Connection.DEBUG_ENABLED = true;
    }

    public static final long START_TIME = System.currentTimeMillis();
    
    private static Logger LOG;
    private boolean lanternStarted = false;
    private GetModeProxy getModeProxy;
    private GiveModeProxy giveModeProxy;
    private JettyLauncher jettyLauncher;
    private XmppHandler xmpp;
    private BrowserService browserService;
    private StatsUpdater statsUpdater;
    private StatsReporter statsReporter;
    
    private LocalCipherProvider localCipherProvider;

    /**
     * Set a dummy message service while we're not fully wired up.
     */
    private MessageService messageService = new MessageService() {

        @Override
        public void showMessage(String title, String message) {
            System.err.println("Title: "+title+"\nMessage: "+message);
        }

        @Override
        @Subscribe
        public void onMessageEvent(final MessageEvent me) {
            showMessage(me.getTitle(), me.getMsg());
        }

        @Override
        public int askQuestion(String title, String message, int typeFlag) {
            showMessage(title, message);
            return 0;
        }
    };

    private Injector injector;
    private SystemTray systemTray;
    Model model;
    private ModelUtils modelUtils;
    private Settings set;

    private InternalState internalState;

    //private final String[] commandLineArgs;
    private SyncService syncService;
    private HttpClientFactory httpClientFactory;
    private final LanternModule lanternModule;
    //private SplashScreen splashScreen;

    private ProxyTracker proxyTracker;

    private LanternKeyStoreManager keyStoreManager;

    /**
     * Separate constructor that allows tests to do things like use mocks for
     * certain classes but still test Lantern end-to-end from startup.
     *
     * @param lm The {@link LanternModule} to use.
     * @param args Command line arguments.
     */
    public Launcher(final LanternModule lm) {
        this.lanternModule = lm;
        Thread.currentThread().setName("Lantern-Main-Thread");
        Thread.setDefaultUncaughtExceptionHandler(new UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(final Thread t, final Throwable e) {
                handleError(e, false);
            }
        });
    }

    /**
     * Starts the proxy from the command line.
     *
     * @param args Any command line arguments.
     */
    public static void main(final String... args) {
        main(true, args);
    }

    /**
     * Starts the proxy from the command line.
     *
     * @param args Any command line arguments.
     */
    public static void main(final boolean configureLogger, final String... args) {
        final Stopwatch earlyWatch = 
            StopwatchManager.getStopwatch("pre-instance-creation", 
                STOPWATCH_LOG, STOPWATCH_GROUP);
        earlyWatch.start();
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
        earlyWatch.stop();
        final LanternModule lm = new LanternModule(cmd);
        final Launcher launcher = new Launcher(lm);
        if (configureLogger) {
            launcher.configureDefaultLogger();
        }
        launcher.launch();
    }

    void launch() {
        LOG = LoggerFactory.getLogger(Launcher.class);
        LOG.info("Starting Lantern...");

        final Stopwatch injectorWatch = 
            StopwatchManager.getStopwatch("Guice-Injector", 
                STOPWATCH_LOG, STOPWATCH_GROUP);
        injectorWatch.start();
        injector = Guice.createInjector(this.lanternModule);
        injectorWatch.stop();
        LOG.debug("Creating display...");

        final Stopwatch preInstanceWatch = 
            StopwatchManager.getStopwatch("Pre-Instance-Creation", 
                STOPWATCH_LOG, STOPWATCH_GROUP);
        preInstanceWatch.start();
        
        final CommandLine cmd = this.lanternModule.commandLine();
        // There are four cases here:
        // 1) We're just starting normally
        // 2) We're running with UI disabled (such as from a server), in
        //    which case we don't show any UI elements
        // 3) We're running on system startup (specified with --launchd flag)
        //    and setup is not complete, in which case we show no splash screen,
        //    but do show the UI at whatever setup step it's currently at
        //    and put the app in the system tray
        // 4) We're running on system startup (specified with --launchd flag)
        //    and setup IS complete, in which case we show no splash screen,
        //    do not show the UI, but do put the app in the system tray.
        final boolean uiDisabled = cmd.hasOption(OPTION_DISABLE_UI);
        final boolean launchD = cmd.hasOption(OPTION_LAUNCHD);

        configureCipherSuites();
        final Display display;
        if (uiDisabled) {
            display = null;
            preInstanceWatch.stop();
        } else {
            Display.setAppName("Lantern Beta");
            display = DisplayWrapper.getDisplay();
            preInstanceWatch.stop();
            // Never show the splash screen on startup, even if setup is
            // not complete.
            if (!launchD) {
                /*
                splashScreen = instance(SplashScreen.class);
                final Stopwatch splashWatch = 
                        StopwatchManager.getStopwatch("Splash-Screen-Init", 
                            STOPWATCH_LOG, STOPWATCH_GROUP);
                splashWatch.start();
                splashScreen.init(display);
                splashWatch.stop();
                */
            }
        }

        model = instance(Model.class);
        set = model.getSettings();
        set.setUiEnabled(!uiDisabled);
        instance(Censored.class);

        messageService = instance(MessageService.class);

        if (SystemUtils.IS_OS_MAC_OSX) {
            final boolean sixtyFourBits =
                System.getProperty("sun.arch.data.model").equals("64");
            if (!sixtyFourBits) {
                messageService.showMessage("Operating System Error",
                        "We're sorry but Lantern requires a 64 bit operating " +
                        "system on OSX! Exiting");
                
                System.exit(0);
            }
        }
        jettyLauncher = instance(JettyLauncher.class);
        
        final Stopwatch jettyWatch = 
                StopwatchManager.getStopwatch("Jetty-Start", 
                    STOPWATCH_LOG, STOPWATCH_GROUP);
        jettyWatch.start();
        jettyLauncher.start();
        jettyWatch.stop();
        modelUtils = instance(ModelUtils.class);
        final boolean showDashboard = 
                shouldShowDashboard(model, uiDisabled, launchD);
        if (showDashboard) {
            browserService = instance(BrowserService.class);
        }
        launchLantern(showDashboard);
        
        keyStoreManager = instance(LanternKeyStoreManager.class);
        instance(NatPmpService.class);
        instance(UpnpService.class);
        instance(LanternTrustStore.class);
        instance(Proxifier.class);
        final boolean showTray = !uiDisabled;

        if (showTray) {
            systemTray = instance(SystemTray.class);
            try {
                systemTray.start();
            } catch (final Exception e) {
                LOG.error("Error starting tray?", e);
            }
        }

        xmpp = instance(DefaultXmppHandler.class);

        localCipherProvider = instance(LocalCipherProvider.class);

        internalState = instance(InternalState.class);
        httpClientFactory = instance(HttpClientFactory.class);
        syncService = instance(SyncService.class);

        proxyTracker = instance(ProxyTracker.class);

        LOG.debug("Processing command line options...");
        processCommandLineOptions(cmd);
        LOG.debug("Processed command line options...");

        instance(GeoIp.class);
        statsUpdater = instance(StatsUpdater.class);
        statsReporter = instance(StatsReporter.class);

        model.getConnectivity().setInternet(false);
        
        // Use our stored STUN servers if available.
        final Collection<String> stunServers = set.getStunServers();
        if (stunServers != null && !stunServers.isEmpty()) {
            LOG.info("Using stored STUN servers: {}", stunServers);
            StunServerRepository.setStunServers(toSocketAddresses(stunServers));
        }
        
        // Set up the give and get mode proxies
        getModeProxy = instance(GetModeProxy.class);
        
        LOG.info("Creating give mode proxy...");
        giveModeProxy = instance(GiveModeProxy.class);
        
        startServices();

        // This is necessary to keep the tray/menu item up in the case
        // where we're not launching a browser.
        // OX: YourKit was reporting deadlocks here.  This seems like a
        // potentially expensive busy loop
        if (display != null) {
            LOG.debug("Looping on display");
            while (!display.isDisposed ()) {
                if (!display.readAndDispatch ()) display.sleep ();
            }
        } else if (!SystemUtils.IS_OS_MAC_OSX) {
            LOG.debug("No display?");
            
            // We just wait here because depending on the OS and what threads
            // happen to have started, it's possible there are no more 
            // non-daemon threads at this point, in which case the JVM will
            // just exit.
            synchronized (this) {
                try {
                    wait();
                } catch (final InterruptedException e) {
                    LOG.debug("Interrupted");
                }
            }
        }
    }

    /**
     * This starts all of the services on a separate thread to avoid holding
     * up the main thread that is in charge of displaying the UI.
     */
    private void startServices() {
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                keyStoreManager.start();
                final ConnectivityChecker connectivityChecker =
                    instance(ConnectivityChecker.class);
                final Timer timer = new Timer();
                timer.schedule(connectivityChecker, 0, 60 * 1000);

                shutdownable(ModelIo.class);
                
                
                try {
                    proxyTracker.start();
                } catch (final Exception e) {
                    LOG.error("Could not start proxy tracker?", e);
                }
                xmpp.start();
                getModeProxy.start();
                giveModeProxy.start();

                syncService.start();
                statsUpdater.start();
                
                // TODO: Maybe report stats only for fallback proxies
                //if (LanternUtils.isFallbackProxy()) {
                    statsReporter.start();
                //}
                
                gnomeAutoStart();
                
                autoConnect();
            }
            
        }, "Launcher-Start-Thread");
        t.setDaemon(true);
        t.start();
    }

    private boolean shouldShowDashboard(final Model mod, 
        final boolean uiDisabled, final boolean launchD) {
        if (mod == null) {
            throw new NullPointerException("Can't have a null model here!");
        }
        if (uiDisabled) {
            return false;
        } else if (launchD) {
            if (model.isSetupComplete()) {
                return false;
            } else {
                return true;
            }
        } else {
            return true;
        }
    }

    private <T> void shutdownable(final Class<T> clazz) {
        instance(clazz);
    }

    private <T> T instance(final Class<T> clazz) {
        final String name = clazz.getSimpleName();
        
        final Stopwatch watch = 
            StopwatchManager.getStopwatch(name, STOPWATCH_LOG, STOPWATCH_GROUP);
        
        watch.start();
        
        LOG.debug("Loading {}", name);
        final T inst = injector.getInstance(clazz);
        if (Shutdownable.class.isAssignableFrom(clazz)) {
            addShutdownHook((Shutdownable) inst);
        }
        if (inst == null) {
            LOG.error("Could not load instance of "+clazz);
            throw new NullPointerException("Could not load instance of "+clazz);
        }
        /*
        if (splashScreen != null) {
            splashScreen.advanceBar();
        }
        */
        watch.stop();
        return inst;
    }

    private void addShutdownHook(final Shutdownable service) {
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

    private void gnomeAutoStart() {
        // Before setup we should just do the default, which is to run on
        // startup. The user can configure this differently at any point
        // hereafter.
        if (!SystemUtils.IS_OS_LINUX) {
            return;
        }
        if (!LanternClientConstants.GNOME_AUTOSTART.isFile()) {
            final File lanternDesktop;
            final File candidate1 =
                new File(LanternClientConstants.GNOME_AUTOSTART.getName());
            final File candidate2 =
                new File("install/linux", LanternClientConstants.GNOME_AUTOSTART.getName());
            if (candidate1.isFile()) {
                lanternDesktop = candidate1;
            } else if (candidate2.isFile()){
                lanternDesktop = candidate2;
            } else {
                LOG.error("Could not find lantern.desktop file");
                return;
            }
            try {
                final File parent = LanternClientConstants.GNOME_AUTOSTART.getParentFile();
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

        // Make sure our launcher entry has the Lantern icon, as opposed to
        // the stock Chrome one.
        LanternUtils.addStartupWMClass(
                "/usr/share/applications/lantern.desktop");
    }

    private static final String CIPHER_SUITE_LOW_BIT =
            "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA";

    private static final String CIPHER_SUITE_HIGH_BIT =
            "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA";

    private static final String STOPWATCH_LOG = "org.lantern.STOPWATCH_LOG";
    
    private static final String STOPWATCH_GROUP = "launcherGroup";

    public static void configureCipherSuites() {
        Security.addProvider(new BouncyCastleProvider());
        if (!LanternUtils.isUnlimitedKeyStrength()) {
            /*
            if (LanternUtils.isDevMode()) {
                System.err.println("PLEASE INSTALL UNLIMITED STRENGTH POLICY FILES WITH ONE OF THE FOLLOWING:\n" +
                    "sudo cp install/java7/* $JAVA_HOME/jre/lib/security/\n" +
                    "sudo cp install/java6/* $JAVA_HOME/jre/lib/security/\n" +
                    "depending on the JVM you're running with. You may want to backup $JAVA_HOME/jre/lib/security as well.\n" +
                    "JAVA_HOME is currently: "+System.getenv("JAVA_HOME"));
                
                // Don't exit if we're running on CI...
                final String env = System.getenv("BAMBOO");
                System.err.println("Env: "+System.getenv());
                if (!"true".equalsIgnoreCase(env)) {
                    System.exit(1);
                }
            }
            */
            if (!SystemUtils.IS_OS_WINDOWS_VISTA) {
                log("No policy files on non-Vista machine!!");
            }
            log("Reverting to weaker ciphers");
            log("Look in "+ new File(SystemUtils.JAVA_HOME, "lib/security").getAbsolutePath());
            IceConfig.setCipherSuites(new String[] {
                    CIPHER_SUITE_LOW_BIT
                //"TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA"
                //"TLS_ECDHE_RSA_WITH_RC4_128_SHA"
            });
        } else {
            // Note the following just sets what cipher suite the server
            // side selects. DHE is for perfect forward secrecy.

            // We include 128 because we never have enough permissions to
            // copy the unlimited strength policy files on Vista, so we have
            // to revert back to 128.
            IceConfig.setCipherSuites(new String[] {
                    CIPHER_SUITE_LOW_BIT,
                    CIPHER_SUITE_HIGH_BIT
                //"TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA",
                //"TLS_DHE_RSA_WITH_AES_128_CBC_SHA"
                //"TLS_RSA_WITH_RC4_128_SHA"
                //"TLS_ECDHE_RSA_WITH_RC4_128_SHA"
            });
        }
    }


    private static void log(final String msg) {
        if (LOG != null) {
            LOG.error(msg);
        } else {
            System.err.println(msg);
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

    private boolean parseOptionDefaultTrue(final CommandLine cmd,
        final String option) {
        if (cmd.hasOption(option)) {
            LOG.info("Found option: "+option);
            return false;
        }

        // DEFAULTS TO TRUE!!
        return true;
    }

    private void loadLocalPasswordFile(final String pwFilename) {
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

    private void launchLantern(final boolean showDashboard) {
        printLaunchTimes();
        
        // Note this is the non-daemon thread that keeps the app alive.
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                LOG.debug("Launching Lantern...");
                if (!modelUtils.isConfigured() && model.getModal() != Modal.settingsLoadFailure) {
                    model.setModal(Modal.welcome);
                }
                if (showDashboard) {
                    browserService.openBrowserWhenPortReady();
                }
            }
            
        }, "Browser-Launching-Thread");
        t.start();

        lanternStarted = true;
    }


    private void printLaunchTimes() {
        LOG.debug("STARTUP TOOK {} MILLISECONDS", 
           System.currentTimeMillis() - START_TIME);
        StopwatchManager.logSummaries(STOPWATCH_LOG);
    }

    private void autoConnect() {
        LOG.debug("Connecting if oauth is configured...");
        // This won't connect in the case where the user hasn't entered
        // their user name and password and the user is running with a UI.
        // Otherwise, it will connect.
        if (modelUtils.isConfigured()) {
            final Runnable runner = new Runnable() {
                @Override
                public void run() {
                    try {
                        xmpp.connect();
                        if (model.getModal() == Modal.connecting) {
                            internalState.advanceModal(null);
                        }
                    } catch (final IOException e) {
                        LOG.debug("Could not login", e);
                    } catch (final CredentialException e) {
                        LOG.debug("Bad credentials");
                    } catch (final NotInClosedBetaException e) {
                        LOG.warn("Not in closed beta!!");
                        internalState.setNotInvited(true);
                    }
                }
            };
            final Thread t = new Thread(runner, "Auto-Starting-Thread");
            t.setDaemon(true);
            t.start();
        } else {
            LOG.debug("Not auto-logging in with model:\n{}", model);
            if (model.isSetupComplete())
                Events.syncModal(model, Modal.authorize);
        }
    }

    private static void printHelp(Options options, String errorMessage) {
        if (errorMessage != null) {
            System.err.println(errorMessage);
        }

        final HelpFormatter formatter = new HelpFormatter();
        formatter.printHelp("lantern", options);
    }

    private static void printVersion() {
        System.out.println("Lantern version "+LanternClientConstants.VERSION);
    }

    void configureDefaultLogger() {
        final String propsPath = "src/main/resources/log4j.properties";
        final File props = new File(propsPath);
        if (props.isFile()) {
            System.out.println("Running from main line");
            PropertyConfigurator.configure(propsPath);
        } else {
            System.out.println("Not on main line...");
            configureProductionLogger();
        }
        System.err.println("CONFIGURED LOGGER");
    }

    private void configureProductionLogger() {
        final File logDir = LanternClientConstants.LOG_DIR;
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
                        json.put("version", LanternClientConstants.VERSION);
                        return true;
                    }
            };

            // We need to do the following because httpClientFactory is still
            // null here. We basically do something reasonable while it's still
            // null.
            final HttpStrategy strategy = new HttpStrategy() {
                private final ProtocolVersion ver =
                    new ProtocolVersion("HTTP", 1, 1);
                private HttpClient client = null;
                @Override
                public HttpResponse execute(final HttpPost request)
                        throws ClientProtocolException, IOException {
                    if (httpClientFactory == null) {
                        return new DefaultHttpResponseFactory().newHttpResponse(
                                ver, 200, null);
                    }
                    if (client == null) {
                        client = httpClientFactory.newClient();
                    }
                    return client.execute(request);
                }

                @Override
                public HttpResponse execute(final HttpGet request)
                        throws ClientProtocolException, IOException {
                    if (httpClientFactory == null) {
                        return new DefaultHttpResponseFactory().newHttpResponse(
                                ver, 200, null);
                    }
                    if (client == null) {
                        client = httpClientFactory.newClient();
                    }
                    return client.execute(request);
                }
            };
            final Appender bugAppender = new ExceptionalAppender(
                LanternClientConstants.GET_EXCEPTIONAL_API_KEY, callback, true,
                Level.WARN, strategy);

            BasicConfigurator.configure(bugAppender);
        } catch (final IOException e) {
            System.out.println("Exception setting log4j props with file: "
                    + logFile);
            e.printStackTrace();
        }
    }

    private void handleError(final Throwable t, final boolean exit) {
        final String msg = msg(t);
        LOG.error("Uncaught exception on" +
                "\nOS_NAME: "+SystemUtils.OS_NAME +
                "\nOS_ARCH: "+SystemUtils.OS_ARCH +
                "\nOS_VERSION: "+SystemUtils.OS_VERSION +
                "\nUSER_COUNTRY: "+SystemUtils.USER_COUNTRY +
                "\nUSER_LANGUAGE: "+SystemUtils.USER_LANGUAGE +
                "\n\n"+msg, t);
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
        else if (!lanternStarted && set != null && set.isUiEnabled()) {
            LOG.info("Showing error to user...");
            messageService.showMessage("Startup Error",
               "We're sorry, but there was an error starting Lantern " +
               "described as '"+msg+"'.");
        }
        if (exit) {
            LOG.info("Exiting Lantern");
            // Give the logger a second to report the error.
            try {Thread.sleep(6000);} catch (final InterruptedException e) {}
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
    public static final String OPTION_DISABLE_UI = "disable-ui";
    public static final String OPTION_HELP = "help";
    public static final String OPTION_LAUNCHD = "launchd";
    public static final String OPTION_PUBLIC_API = "public-api";
    public static final String OPTION_SERVER_PORT = "server-port";
    public static final String OPTION_DISABLE_KEYCHAIN = "disable-keychain";
    public static final String OPTION_PASSWORD_FILE = "password-file";
    public static final String OPTION_TRUSTED_PEERS = "disable-trusted-peers";
    public static final String OPTION_ANON_PEERS ="disable-anon-peers";
    public static final String OPTION_LAE = "disable-lae";
    public static final String OPTION_CENTRAL = "disable-central";
    public static final String OPTION_UDP_PROXY_PRIORITY = "udp-proxy-priority";
    public static final String OPTION_UDP = "disable-udp";
    public static final String OPTION_TCP = "disable-tcp";
    public static final String OPTION_USER = "user";
    public static final String OPTION_PASS = "pass";
    public static final String OPTION_GET = "force-get";
    public static final String OPTION_GIVE = "force-give";
    public static final String OPTION_VERSION = "version";
    public static final String OPTION_NEW_UI = "new-ui";
    public static final String OPTION_REFRESH_TOK = "refresh-tok";
    public static final String OPTION_ACCESS_TOK = "access-tok";
    public static final String OPTION_OAUTH2_CLIENT_SECRETS_FILE = "oauth2-client-secrets-file";
    public static final String OPTION_OAUTH2_USER_CREDENTIALS_FILE = "oauth2-user-credentials-file";
    public static final String OPTION_CONTROLLER_ID = "controller-id";
    public static final String OPTION_INSTANCE_ID = "instance-id";
    public static final String OPTION_AS_FALLBACK = "as-fallback-proxy";
    public static final String OPTION_KEYSTORE = "keystore";
    
    public static Options buildOptions() {
        final Options options = new Options();
        options.addOption(null, OPTION_DISABLE_UI, false,
            "run without a graphical user interface.");
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
        options.addOption(null, OPTION_UDP_PROXY_PRIORITY, true,
                "set the priority of UDP proxies relative to TCP, one of 'lower', 'same', or 'higher', defaults to 'lower'");
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
        options.addOption(null, OPTION_VERSION, false,
            "Print the Lantern version");
        options.addOption(null, OPTION_NEW_UI, false,
            "Use the new UI under the 'ui' directory");
        options.addOption(null, OPTION_REFRESH_TOK, true,
                "Specify the oauth2 refresh token");
        options.addOption(null, OPTION_ACCESS_TOK, true,
                "Specify the oauth2 access token");
        options.addOption(null, OPTION_OAUTH2_CLIENT_SECRETS_FILE, true,
            "read Google OAuth2 client secrets from the file specified");
        options.addOption(null, OPTION_OAUTH2_USER_CREDENTIALS_FILE, true,
            "read Google OAuth2 user credentials from the file specified");
        options.addOption(null, OPTION_CONTROLLER_ID, true,
            "GAE id of the lantern-controller");
        options.addOption(null, OPTION_INSTANCE_ID, true,
            "Identifier for this instance in the lantern-controller");
        options.addOption(null, OPTION_AS_FALLBACK, false,
            "Run as fallback proxy");
        options.addOption(null, OPTION_KEYSTORE, true,
            "[XXX: perhaps provisional] path to keystore file where the fallback proxy should find its own keypair.");
        return options;
    }


    private void processCommandLineOptions(final CommandLine cmd) {

        final String ctrlOpt = OPTION_CONTROLLER_ID;
        if (cmd.hasOption(ctrlOpt)) {
            LanternClientConstants.setControllerId(
                cmd.getOptionValue(ctrlOpt));
        }

        final String insOpt = OPTION_INSTANCE_ID;
        if (cmd.hasOption(insOpt)) {
            model.setInstanceId(cmd.getOptionValue(insOpt));
        }

        final String fbOpt = OPTION_AS_FALLBACK;
        if (cmd.hasOption(fbOpt)) {
            LanternUtils.setFallbackProxy(true);
        }

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
        set.setUdpProxyPriority(cmd.getOptionValue(OPTION_UDP_PROXY_PRIORITY, "lower").toUpperCase());
        
        final boolean tcp = parseOptionDefaultTrue(cmd, OPTION_TCP);
        final boolean udp = parseOptionDefaultTrue(cmd, OPTION_UDP);
        IceConfig.setTcp(tcp);
        IceConfig.setUdp(udp);
        set.setTcp(tcp);
        set.setUdp(udp);

        /*
        if (cmd.hasOption(OPTION_USER)) {
            set.setUserId(cmd.getOptionValue(OPTION_USER));
        }
        if (cmd.hasOption(OPTION_PASS)) {
            set.(cmd.getOptionValue(OPTION_PASS));
        }
        */

        if (cmd.hasOption(OPTION_ACCESS_TOK)) {
            set.setAccessToken(cmd.getOptionValue(OPTION_ACCESS_TOK));
        }
        
        if (cmd.hasOption(OPTION_REFRESH_TOK)) {
            final String refresh = cmd.getOptionValue(OPTION_REFRESH_TOK);
            set.setRefreshToken(refresh);
            Events.asyncEventBus().post(new RefreshTokenEvent(refresh));
        }
        // option to disable use of keychains in local privacy
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

        LOG.info("Running API on port: {}", StaticSettings.getApiPort());
        if (cmd.hasOption(OPTION_LAUNCHD)) {
            LOG.debug("Running from launchd or launchd set on command line");
            model.setLaunchd(true);
        } else {
            model.setLaunchd(false);
        }

        if (cmd.hasOption(OPTION_GIVE)) {
            model.getSettings().setMode(Mode.give);
        } else if (cmd.hasOption(OPTION_GET)) {
            model.getSettings().setMode(Mode.get);
        }
    }

    public Injector getInjector() {
        return injector;
    }
}
