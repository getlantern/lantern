package org.lantern;

import java.io.File;
import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.Timer;

import javax.crypto.Cipher;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang3.SystemUtils;
import org.jivesoftware.smack.SASLAuthentication;
import org.kaleidoscope.BasicRandomRoutingTable;
import org.kaleidoscope.RandomRoutingTable;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.http.GoogleOauth2RedirectServlet;
import org.lantern.http.InteractionServlet;
import org.lantern.http.JettyLauncher;
import org.lantern.http.PhotoServlet;
import org.lantern.kscope.DefaultKscopeAdHandler;
import org.lantern.kscope.KscopeAdHandler;
import org.lantern.monitoring.StatsManager;
import org.lantern.network.NetworkTracker;
import org.lantern.oauth.LanternSaslGoogleOAuth2Mechanism;
import org.lantern.privacy.DefaultEncryptedFileService;
import org.lantern.privacy.DefaultLocalCipherProvider;
import org.lantern.privacy.EncryptedFileService;
import org.lantern.privacy.LocalCipherProvider;
import org.lantern.privacy.MacLocalCipherProvider;
import org.lantern.privacy.SecretServiceLocalCipherProvider;
import org.lantern.privacy.UnencryptedFileService;
import org.lantern.privacy.WindowsLocalCipherProvider;
import org.lantern.proxy.CertTrackingSslEngineSource;
import org.lantern.proxy.DefaultProxyTracker;
import org.lantern.proxy.DispatchingChainedProxyManager;
import org.lantern.proxy.GetModeProxy;
import org.lantern.proxy.GiveModeProxy;
import org.lantern.proxy.ProxyTracker;
import org.lantern.proxy.UdtServerFiveTupleListener;
import org.lantern.state.CometDSyncStrategy;
import org.lantern.state.DefaultFriendsHandler;
import org.lantern.state.DefaultModelService;
import org.lantern.state.DefaultModelUtils;
import org.lantern.state.FriendsHandler;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;
import org.lantern.state.ModelService;
import org.lantern.state.ModelUtils;
import org.lantern.state.SyncService;
import org.lantern.state.SyncStrategy;
import org.lantern.ui.NotificationManager;
import org.lantern.ui.SwingMessageService;
import org.lantern.util.DefaultHttpClientFactory;
import org.lantern.util.HttpClientFactory;
import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.UpnpService;
import org.littleshoot.commom.xmpp.XmppConnectionRetyStrategyFactory;
import org.littleshoot.proxy.ChainedProxyManager;
import org.littleshoot.proxy.SslEngineSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.AbstractModule;
import com.google.inject.Provides;
import com.google.inject.Singleton;

public class LanternModule extends AbstractModule {

    private static final Logger log =
        LoggerFactory.getLogger(LanternModule.class);
    
    private static LanternModule s_instance;

    private NatPmpService natPmpService;

    private UpnpService upnpService;
    private GeoIpLookupService geoIpLookupService;
    private final org.apache.commons.cli.CommandLine commandLine;
    
    public LanternModule(final String[] args) {
        final Cli cli = new Cli(args);
        this.commandLine = cli.getParsedCommandLine();
        s_instance = this;
    }
    
    public static LanternModule getInstance() {
        return s_instance;
    }
    
    @Override
    protected void configure() {
        SASLAuthentication.registerSASLMechanism("X-OAUTH2",
            LanternSaslGoogleOAuth2Mechanism.class);

        bind(NetworkTracker.class);
        bind(ModelUtils.class).to(DefaultModelUtils.class);
        bind(HttpClientFactory.class).to(DefaultHttpClientFactory.class);
        bind(LanternSocketsUtil.class);
        bind(LanternXmppUtil.class);
        bind(MessageService.class).to(SwingMessageService.class);
        bind(KscopeAdHandler.class).to(DefaultKscopeAdHandler.class);
        bind(XmppConnectionRetyStrategyFactory.class).to(LanternXmppRetryStrategyFactory.class);

        bind(FriendsHandler.class).to(DefaultFriendsHandler.class);
        bind(PeerFactory.class).to(DefaultPeerFactory.class);
        bind(ProxyService.class).to(Proxifier.class);
        bind(SyncStrategy.class).to(CometDSyncStrategy.class);
        bind(SyncService.class);
        //bind(EncryptedFileService.class).to(DefaultEncryptedFileService.class);
        bind(BrowserService.class).to(ChromeBrowserService.class);
        bind(Model.class).toProvider(ModelIo.class).in(Singleton.class);

        bind(ModelService.class).to(DefaultModelService.class);

        bind(RandomRoutingTable.class).to(BasicRandomRoutingTable.class);

        //bind(HttpsEverywhere.class);
        bind(Roster.class);
        bind(InteractionServlet.class);
        bind(LanternTrustStore.class);
        bind(PhotoServlet.class);
        bind(LogglyHelper.class);

        bind(Censored.class).to(DefaultCensored.class);
        bind(ProxyTracker.class).to(DefaultProxyTracker.class);
        bind(XmppHandler.class).to(DefaultXmppHandler.class);
        //bind(PeerProxyManager.class).to(DefaultPeerProxyManager.class);
        bind(GoogleOauth2RedirectServlet.class);
        bind(JettyLauncher.class);
        bind(AppIndicatorTray.class);
        bind(GetModeProxy.class);
        bind(StatsManager.class);
        bind(ConnectivityChecker.class);
        bind(CountryService.class);
        bind(NotificationManager.class);
        bind(ChainedProxyManager.class).to(DispatchingChainedProxyManager.class);
        bind(SslEngineSource.class).to(CertTrackingSslEngineSource.class);
        bind(GetModeProxy.class);
        bind(GiveModeProxy.class);
        bind(UdtServerFiveTupleListener.class);

        try {
            copyFireFoxExtension();
        } catch (final IOException e) {
            log.error("Could not copy FireFox extension?", e);
        }
    }
    
    @Provides @Singleton
    public org.apache.commons.cli.CommandLine commandLine() {
        return this.commandLine;
    }

    @Provides @Singleton
    public GeoIpLookupService provideGeoIpLookupService() {
        // Testing.
        if (this.geoIpLookupService != null) {
            return this.geoIpLookupService;
        }
        return new GeoIpLookupService();
    }

    @Provides @Singleton
    public UpnpService provideUpnpService(final Model model) {
        // Testing.
        if (this.upnpService != null) {
            return this.upnpService;
        }
        return new Upnp(model);
    }

    @Provides @Singleton
    public NatPmpService provideNatPmpService(final Model model) {
        // Testing.
        if (this.natPmpService != null) {
            return this.natPmpService;
        }
        natPmpService = new NatPmpImpl(model);
        return natPmpService;
    }

    @Provides @Singleton
    public EncryptedFileService provideEncryptedService(
        final LocalCipherProvider lcp) {
        if (LanternUtils.isTesting()) {
            return new UnencryptedFileService();
        }
        return new DefaultEncryptedFileService(lcp);
    }

    @Provides @Singleton
    SystemTray provideSystemTray(final BrowserService browserService,
        final Model model) {
        if (SystemUtils.IS_OS_LINUX) {
            try {
                return new AppIndicatorTray(browserService, model);
            } catch (final java.lang.UnsatisfiedLinkError ex) {
                log.warn("no supported version of appindicator libs found, "
                         + "falling back to generic system tray");
            }
        }
        return new SystemTrayImpl(browserService, model);
    }

    @Provides @Singleton
    Timer provideTimer() {
        return new Timer("Lantern-Timer", true);
    }

    @Provides  @Singleton
    public LocalCipherProvider provideLocalCipher() {
        if (LanternUtils.isTesting()) {
            return newBasicCipherProvider();
        }
        if (SystemUtils.IS_OS_WINDOWS) {
            return new WindowsLocalCipherProvider();
        } else if (SystemUtils.IS_OS_MAC_OSX) {
            return new MacLocalCipherProvider();
            //lcp = new DefaultLocalCipherProvider();
        } else if (SystemUtils.IS_OS_LINUX &&
                 SecretServiceLocalCipherProvider.secretServiceAvailable()) {
            return new SecretServiceLocalCipherProvider();
        }
        else {
            return new DefaultLocalCipherProvider();
        }
    }

    private LocalCipherProvider newBasicCipherProvider() {
        return new LocalCipherProvider() {

            @Override
            public Cipher newLocalCipher(int opmode) throws IOException,
                    GeneralSecurityException {
                return Cipher.getInstance("AES/CBC/PKCS5Padding");
            }

            @Override
            public boolean requiresAdditionalUserInput() {return false;}

            @Override
            public void feedUserInput(char[] input, boolean init)
                    throws IOException, GeneralSecurityException {}
            @Override
            public boolean isInitialized() {return true;}
            @Override
            public void reset() throws IOException {}
            
        };
    }

    /**
     * Copies our FireFox extension to the appropriate place.
     *
     * @return The {@link File} for the final destination directory of the
     * extension.
     * @throws IOException If there's an error copying the extension.
     */
    public void copyFireFoxExtension() throws IOException {
        log.info("Copying FireFox extension");
        final File dir = getExtensionDir();
        if (!dir.isDirectory()) {
            log.info("Making FireFox extension directory...");
            // NOTE: This likely means the user does not have FireFox. We copy
            // the extension here anyway in case the user ever installs
            // FireFox in the future.
            if (!dir.mkdirs()) {
                log.error("Could not create ext dir: "+dir);
                throw new IOException("Could not create ext dir: "+dir);
            }
        }
        final String extName = "lantern@getlantern.org";
        final File dest = new File(dir, extName);
        final File ffDir = new File("firefox/"+extName);
        if (dest.exists() && !FileUtils.isFileNewer(ffDir, dest)) {
            log.info("Extension already exists and ours is not newer");
            return;
        }
        if (!ffDir.isDirectory()) {
            log.error("No extension directory found at {}", ffDir);
            throw new IOException("Could not find extension?");
        }
        FileUtils.copyDirectoryToDirectory(ffDir, dir);
        log.info("Copied FireFox extension from {} to {}", ffDir, dir);
    }

    public File getExtensionDir() {
        final File userHome = SystemUtils.getUserHome();
        if (SystemUtils.IS_OS_WINDOWS) {
            final File ffDir = new File(System.getenv("APPDATA"), "Mozilla");
            return new File(ffDir, "Extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}");
        } else if (SystemUtils.IS_OS_MAC_OSX) {
            return new File(userHome,
                "Library/Application Support/Mozilla/Extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}");
        } else {
            return new File(userHome, "Mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}");
        }
    }

    public void setNatPmpService(NatPmpService natPmpService) {
        this.natPmpService = natPmpService;
    }
    public void setUpnpService(UpnpService upnpService) {
        this.upnpService = upnpService;
    }

    public void setGeoIpLookupService(GeoIpLookupService geoIpLookupService) {
        this.geoIpLookupService = geoIpLookupService;
    }
}
