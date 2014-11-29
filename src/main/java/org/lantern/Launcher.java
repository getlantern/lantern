package org.lantern;

import java.io.File;
import java.io.IOException;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.lang.Thread.UncaughtExceptionHandler;
import java.net.InetSocketAddress;
import java.nio.file.Files;
import java.util.Collection;
import java.util.HashSet;
import java.util.Properties;
import java.util.Timer;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.io.FileUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.SystemUtils;
import org.apache.log4j.AsyncAppender;
import org.apache.log4j.BasicConfigurator;
import org.apache.log4j.Level;
import org.apache.log4j.PatternLayout;
import org.apache.log4j.PropertyConfigurator;
import org.lantern.event.Events;
import org.lantern.event.MessageEvent;
import org.lantern.event.PublicIpAndTokenTracker;
import org.lantern.http.JettyLauncher;
import org.lantern.loggly.LogglyAppender;
import org.lantern.monitoring.StatsManager;
import org.lantern.papertrail.PapertrailAppender;
import org.lantern.privacy.LocalCipherProvider;
import org.lantern.proxy.GetModeProxy;
import org.lantern.proxy.GiveModeProxy;
import org.lantern.proxy.ProxyTracker;
import org.lantern.proxy.pt.FlashlightServerManager;
import org.lantern.state.FriendsHandler;
import org.lantern.state.InternalState;
import org.lantern.state.Modal;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;
import org.lantern.state.ModelUtils;
import org.lantern.state.Settings;
import org.lantern.state.SyncService;
import org.lantern.util.HttpClientFactory;
import org.lantern.util.Stopwatch;
import org.lantern.util.StopwatchManager;
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
    private static Launcher s_instance;
    
    private boolean lanternStarted = false;
    private GetModeProxy getModeProxy;
    private GiveModeProxy giveModeProxy;
    private JettyLauncher jettyLauncher;
    private XmppHandler xmpp;
    private BrowserService browserService;
    private StatsManager statsManager;
    private FriendsHandler friendsHandler;
    private FlashlightServerManager flashlightServerManager;
    
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
        public boolean askQuestion(String title, String message) {
            return false;
        }

        @Override
        public boolean okCancel(String title, String message) {
            return false;
        }
    };

    private Injector injector;
    private SystemTray systemTray;
    Model model;
    private ModelUtils modelUtils;
    private Settings set;

    private SyncService syncService;
    private HttpClientFactory httpClientFactory;
    private final LanternModule lanternModule;

    private ProxyTracker proxyTracker;

    private LanternKeyStoreManager keyStoreManager;

    private S3ConfigFetcher s3ConfigFetcher;

    private PublicIpInfoHandler publicIpInfoHandler;
    
    private PublicIpAndTokenTracker publicIpAndTokenTracker;
    
    private Object initLock = new Object();

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
        s_instance = this;
        
        Events.register(this);
    }
    
    public static Launcher getInstance() {
        return s_instance;
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
        final LanternModule lm = new LanternModule(args);
        final Launcher launcher = new Launcher(lm);
        if (configureLogger) {
            launcher.configureDefaultLogger();
        }
        earlyWatch.stop();
        launcher.launch();
    }

    void launch() {
        LOG = LoggerFactory.getLogger(Launcher.class);
        LOG.info("Starting Lantern...");

        // Fail fast on message keys.
        MessageKey.values();
        
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
        final boolean checkFallbacks = cmd.hasOption(Cli.OPTION_CHECK_FALLBACKS);

        // There are four cases here:
        // 1) We're just starting normally
        // 2) We're running with --disable-ui (or a flag that implies it), in
        //    which case we don't show any UI elements
        // 3) We're running on system startup (specified with --launchd flag)
        //    and setup is not complete, in which case we show no splash screen,
        //    but do show the UI at whatever setup step it's currently at
        //    and put the app in the system tray
        // 4) We're running on system startup (specified with --launchd flag)
        //    and setup IS complete, in which case we show no splash screen,
        //    do not show the UI, but do put the app in the system tray.
        final boolean uiDisabled = checkFallbacks || cmd.hasOption(Cli.OPTION_DISABLE_UI);
        final boolean launchD = cmd.hasOption(Cli.OPTION_LAUNCHD);

        preInstanceWatch.stop();

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

        publicIpAndTokenTracker = instance(PublicIpAndTokenTracker.class);
        instance(XmppConnector.class);
        
        publicIpInfoHandler = instance(PublicIpInfoHandler.class);
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
        
        proxyTracker = instance(ProxyTracker.class);
        httpClientFactory = instance(HttpClientFactory.class);

        s3ConfigFetcher = instance(S3ConfigFetcher.class);
        
        if (checkFallbacks) {
            LOG.debug("Running in check-fallbacks mode");
            String configFolderPath = cmd.getOptionValue(Cli.OPTION_CHECK_FALLBACKS);
            try {
                final FallbackChecker fbc = new FallbackChecker(proxyTracker, 
                        configFolderPath, httpClientFactory);
                Thread t = new Thread(fbc);
                t.start();
            } catch (Exception e) {
                LOG.error("Error instantiating FallbackChecker:");
                e.printStackTrace();
                System.exit(1);
            }
        }

        xmpp = instance(DefaultXmppHandler.class);

        instance(LocalCipherProvider.class);

        instance(InternalState.class);
        syncService = instance(SyncService.class);

        statsManager = instance(StatsManager.class);

        flashlightServerManager = instance(FlashlightServerManager.class);
        
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
        
        friendsHandler = instance(FriendsHandler.class);
        
        startServices(checkFallbacks);
        
        if (uiDisabled) {
            // Run a little main loop to keep the program running
            while (true) {
                try {
                    Thread.sleep(1000);
                } catch (InterruptedException ie) {
                    // do nothing
                }
            }
        }
    }

    /**
     * This starts all of the services on a separate thread to avoid holding
     * up the main thread that is in charge of displaying the UI.
     */
    private void startServices(final boolean checkFallbacks) {
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                keyStoreManager.start();

                shutdownable(ModelIo.class);
                
                // don't need to start the rest of these services when running in check-fallbacks mode
                if (checkFallbacks) {
                    return;
                }
                
                // Immediately start getModeProxy
                getModeProxy.start();
                
                if (!checkFallbacks) {
                    configureLoggly();
                    configurePapertrail();
                }

                final ConnectivityChecker connectivityChecker =
                    instance(ConnectivityChecker.class);

                final Timer timer = new Timer("Connectivity-Check-Timer", true);
                timer.schedule(connectivityChecker, 0, 10 * 1000);
                
                // Immediately start giveModeProxy if we're already in Give mode
                if (Mode.give == model.getSettings().getMode()) {
                    giveModeProxy.start();
                }

                syncService.start();
                gnomeAutoStart();
                
                // If for some reason oauth isn't configured but setup is 
                // complete, try to authorize again.
                if (!modelUtils.isConfigured()) {
                    LOG.debug("Not auto-logging in with model:\n{}", model);
                    if (model.isSetupComplete())
                        Events.syncModal(model, Modal.authorize);
                }
            }
            
        }, "Launcher-Start-Thread");
        t.setDaemon(true);
        t.start();
    }
    
    @Subscribe
    public void onConnectivityChanged(final ConnectivityChangedEvent event) {
        synchronized(initLock) {
            if (event.isConnected()) {
                startNetworkServices();
            } else {
                stopNetworkServices();
            }
        }
    }
    
    private void startNetworkServices() {
        // Try to initialize network services once
        try {
            publicIpAndTokenTracker.reset();
            s3ConfigFetcher.init();
            proxyTracker.init();
            // Needs a fallback.
            //publicIpInfoHandler.init();
            
            // Once network services are successfully initialized, start
            // background tasks.
            s3ConfigFetcher.start();
            proxyTracker.start();
        } catch (final InitException e) {
            LOG.debug("Something couldn't connect: {}", e.getMessage(), e);
        } catch (final Throwable t) {
            LOG.error("Unexpected error trying to start network services: {}",
                    t.getMessage(), t);
        }
    }
    
    private void stopNetworkServices() {
        xmpp.stop();
        statsManager.stop();
        friendsHandler.stop();
        proxyTracker.stop();
        s3ConfigFetcher.stop();
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
        
        if (inst == null) {
            LOG.error("Could not load instance of "+clazz);
            throw new NullPointerException("Could not load instance of "+clazz);
        }
        
        LOG.debug("Loaded class {}", inst.getClass());
        if (Shutdownable.class.isAssignableFrom(inst.getClass())) {
            addShutdownHook((Shutdownable) inst);
        }
        watch.stop();
        return inst;
    }
    
    public <T> T lookup(Class<T> clazz) {
        return injector.getInstance(clazz);
    }
    
    public Model getModel() {
        return model;
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

    private static final String STOPWATCH_LOG = "org.lantern.STOPWATCH_LOG";
    
    private static final String STOPWATCH_GROUP = "launcherGroup";

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

    void configureDefaultLogger() {
        final File logDir = LanternClientConstants.LOG_DIR;
        File log4jProps = new File(logDir, LanternClientConstants.LOG4J_PROPS_NAME);
        if (LanternUtils.isDevMode()) {
            System.out.println("Running from source");
            File f = new File(LanternClientConstants.LOG4J_PROPS_PATH);
            try {
                Files.copy(f.toPath(), log4jProps.toPath());
            } catch (final IOException e) {
                System.out.println("Exception copying log4j props file: "
                    + f.getPath());
                e.printStackTrace();
           }
        } else {
            System.out.println("Not on main line...");
            configureProductionLogger(logDir, log4jProps);
        }
        PropertyConfigurator.configureAndWatch(log4jProps.getPath());
        System.out.println("Set log4j properties file: " + log4jProps);
        System.out.println("CONFIGURED LOGGER");
    }

    private void configureProductionLogger(File logDir, File log4jProps) {
        final File logFile = new File(logDir, "java.log");
        final Properties props = new Properties();
        try {
            final String logPath = logFile.getCanonicalPath();
            props.put("log4j.appender.RollingTextFile.File", logPath);
            props.put("log4j.rootLogger", "info, RollingTextFile");
            props.put("log4j.appender.RollingTextFile",
                    "org.apache.log4j.RollingFileAppender");
            props.put("log4j.appender.RollingTextFile.MaxFileSize", "1MB");
            props.put("log4j.appender.RollingTextFile.MaxBackupIndex", "1");
            props.put("log4j.appender.RollingTextFile.layout",
                    "org.apache.log4j.PatternLayout");
            props.put(
                    "log4j.appender.RollingTextFile.layout.ConversionPattern",
                    "%-6r %d{ISO8601} %-5p [%t] %c{2}.%M (%F:%L) - %m%n");

            OutputStream output = new FileOutputStream(log4jProps);
            props.store(output, null);
            System.out.println("Set logger file to: " + logPath);
        } catch (final IOException e) {
            System.out.println("Exception setting log4j props with file: "
                    + logFile);
            e.printStackTrace();
        }
    }
    
    private void configureLoggly() {
        LOG.info("Configuring LogglyAppender");
        LogglyAppender logglyAppender = new LogglyAppender(model, LanternUtils.isDevMode());
        final AsyncAppender asyncAppender = new AsyncAppender();
        asyncAppender.addAppender(logglyAppender);
        asyncAppender.setThreshold(Level.WARN);
        asyncAppender.setBlocking(false);
        asyncAppender.setBufferSize(LanternClientConstants.ASYNC_APPENDER_BUFFER_SIZE);
        BasicConfigurator.configure(asyncAppender);
        // When shutting down, we may see exceptions because someone is
        // still using the system while we're shutting down.  Let's not
        // send these to Loggly.
        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
            @Override
            public void run() {
                org.apache.log4j.Logger.getRootLogger().removeAppender(asyncAppender);
            }
        }, "Disable-Loggly-Logging-on-Shutdown"));
    }
    
    private void configurePapertrail() {
        LOG.info("Configuring PapertrailAppender");
        PapertrailAppender papertrailAppender = new PapertrailAppender(
                model,
                instance(ProxySocketFactory.class),
                instance(Censored.class),
                new PatternLayout("[%t] %c{2}.%M (%F:%L) - %m%n"));
        final AsyncAppender asyncAppender = new AsyncAppender();
        asyncAppender.addAppender(papertrailAppender);
        asyncAppender.setThreshold(Level.DEBUG);
        asyncAppender.setBlocking(false);
        asyncAppender.setBufferSize(LanternClientConstants.ASYNC_APPENDER_BUFFER_SIZE);
        BasicConfigurator.configure(asyncAppender);
        // When shutting down, we may see exceptions because someone is
        // still using the system while we're shutting down.  Let's not
        // send these to Papertrail.
        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
            @Override
            public void run() {
                org.apache.log4j.Logger.getRootLogger().removeAppender(asyncAppender);
            }
        }, "Disable-Papertrail-Logging-on-Shutdown"));
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
        if (t instanceof UnsatisfiedLinkError &&
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

    public Injector getInjector() {
        return injector;
    }
}
