package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.Timer;
import java.util.concurrent.Executors;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang3.SystemUtils;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.group.DefaultChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.ServerSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioServerSocketChannelFactory;
import org.jboss.netty.util.HashedWheelTimer;
import org.jboss.netty.util.ThreadNameDeterminer;
import org.jboss.netty.util.ThreadRenamingRunnable;
import org.kaleidoscope.BasicRandomRoutingTable;
import org.kaleidoscope.RandomRoutingTable;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.http.GeoIp;
import org.lantern.http.GoogleOauth2RedirectServlet;
import org.lantern.http.InteractionServlet;
import org.lantern.http.JettyLauncher;
import org.lantern.http.PhotoServlet;
import org.lantern.httpseverywhere.HttpsEverywhere;
import org.lantern.kscope.DefaultKscopeAdHandler;
import org.lantern.kscope.KscopeAdHandler;
import org.lantern.privacy.DefaultEncryptedFileService;
import org.lantern.privacy.DefaultLocalCipherProvider;
import org.lantern.privacy.EncryptedFileService;
import org.lantern.privacy.LocalCipherProvider;
import org.lantern.privacy.MacLocalCipherProvider;
import org.lantern.privacy.SecretServiceLocalCipherProvider;
import org.lantern.privacy.WindowsLocalCipherProvider;
import org.lantern.state.CometDSyncStrategy;
import org.lantern.state.DefaultModelService;
import org.lantern.state.DefaultModelUtils;
import org.lantern.state.InviteQueue;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;
import org.lantern.state.ModelService;
import org.lantern.state.ModelUtils;
import org.lantern.state.SyncService;
import org.lantern.state.SyncStrategy;
import org.lantern.state.Transfers;
import org.lantern.state.TransfersIo;
import org.lantern.ui.SwtMessageService;
import org.lantern.util.GlobalLanternServerTrafficShapingHandler;
import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.UpnpService;
import org.littleshoot.proxy.HandshakeHandlerFactory;
import org.littleshoot.proxy.HttpRequestFilter;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.proxy.PublicIpsOnlyRequestFilter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.util.concurrent.ThreadFactoryBuilder;
import com.google.inject.AbstractModule;
import com.google.inject.Provides;
import com.google.inject.Singleton;

public class LanternModule extends AbstractModule { 
    
    private static final Logger log = 
        LoggerFactory.getLogger(LanternModule.class);
    private LocalCipherProvider localCipherProvider;
    
    private EncryptedFileService encryptedFileService;
    
    private NatPmpService natPmpService;
    
    private UpnpService upnpService;
    private GeoIpLookupService geoIpLookupService;

    @Override 
    protected void configure() {
        // Tweak Netty naming...
        ThreadRenamingRunnable.setThreadNameDeterminer(
                ThreadNameDeterminer.CURRENT);
        
        bind(org.jboss.netty.util.Timer.class).to(HashedWheelTimer.class);
        bind(ModelUtils.class).to(DefaultModelUtils.class);
        bind(HttpRequestFilter.class).to(PublicIpsOnlyRequestFilter.class);
        bind(Stats.class).to(StatsTracker.class);
        bind(LanternSocketsUtil.class);
        bind(LanternXmppUtil.class);
        bind(MessageService.class).to(SwtMessageService.class);
        bind(KscopeAdHandler.class).to(DefaultKscopeAdHandler.class);
        
        bind(PeerFactory.class).to(DefaultPeerFactory.class);
        bind(ProxyService.class).to(Proxifier.class);
        bind(SyncStrategy.class).to(CometDSyncStrategy.class);
        bind(SyncService.class);
        bind(TransfersIo.class);
        //bind(EncryptedFileService.class).to(DefaultEncryptedFileService.class);
        bind(BrowserService.class).to(ChromeBrowserService.class);
        bind(Transfers.class).toProvider(TransfersIo.class).in(Singleton.class);
        bind(Model.class).toProvider(ModelIo.class).in(Singleton.class);
        
        bind(ModelService.class).to(DefaultModelService.class);

        bind(RandomRoutingTable.class).to(BasicRandomRoutingTable.class);
        
        bind(HttpsEverywhere.class);
        bind(Roster.class);
        bind(InteractionServlet.class);
        bind(KeyStoreManager.class).to(LanternKeyStoreManager.class);
        bind(LanternTrustStore.class);
        bind(GlobalLanternServerTrafficShapingHandler.class);
        bind(HandshakeHandlerFactory.class).to(CertTrackingSslHandlerFactory.class);
        bind(SslHttpProxyServer.class);
        bind(PlainTextRelayHttpProxyServer.class);
        bind(PhotoServlet.class);
        bind(LanternFeedback.class);
        
        bind(Censored.class).to(DefaultCensored.class);
        bind(ProxyTracker.class).to(DefaultProxyTracker.class);
        bind(XmppHandler.class).to(DefaultXmppHandler.class);
        //bind(PeerProxyManager.class).to(DefaultPeerProxyManager.class);
        bind(GoogleOauth2RedirectServlet.class);
        bind(JettyLauncher.class);
        bind(AppIndicatorTray.class);
        bind(LanternHttpProxyServer.class);
        bind(StatsUpdater.class);
        bind(ConnectivityChecker.class);
        bind(InviteQueue.class);
        bind(GeoIp.class);
        bind(CountryService.class);
        bind(SplashScreen.class);

        try {
            copyFireFoxExtension();
        } catch (final IOException e) {
            log.error("Could not copy FireFox extension?", e);
        }
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
    public UpnpService provideUpnpService(final Stats stats) {
        // Testing.
        if (this.upnpService != null) {
            return this.upnpService;
        }
        return new Upnp(stats);
    }
    
    @Provides @Singleton
    public NatPmpService provideNatPmpService(final Stats stats) {
        // Testing.
        if (this.natPmpService != null) {
            return this.natPmpService;
        }
        natPmpService = new NatPmpImpl(stats);
        return natPmpService;
    }

    @Provides @Singleton
    public EncryptedFileService provideEncryptedService(
        final LocalCipherProvider lcp) {
        if (this.encryptedFileService != null) {
            return this.encryptedFileService;
        }
        return new DefaultEncryptedFileService(lcp);
    }
    
    @Provides @Singleton
    SystemTray provideSystemTray(final BrowserService browserService, 
        final Model model) {
        if (SystemUtils.IS_OS_LINUX) {
            return new AppIndicatorTray(browserService, model);
        } else {
            return new SystemTrayImpl(browserService, model);
        }
    }
    
    @Provides @Singleton
    ChannelGroup provideChannelGroup() {
        return new DefaultChannelGroup("LanternChannelGroup");
    }
    
    @Provides @Singleton
    Timer provideTimer() {
        return new Timer("Lantern-Timer", true);
    }
    
    @Provides  @Singleton
    public LocalCipherProvider provideLocalCipher() {
        if (this.localCipherProvider != null) {
            return this.localCipherProvider;
        }
        final LocalCipherProvider lcp; 
        
        /*
        if (!settings().isKeychainEnabled()) {
            lcp = new DefaultLocalCipherProvider();
        }
        */
        if (SystemUtils.IS_OS_WINDOWS) {
            lcp = new WindowsLocalCipherProvider();   
        } else if (SystemUtils.IS_OS_MAC_OSX) {
            lcp = new MacLocalCipherProvider();
            //lcp = new DefaultLocalCipherProvider();
        } else if (SystemUtils.IS_OS_LINUX &&
                 SecretServiceLocalCipherProvider.secretServiceAvailable()) {
            lcp = new SecretServiceLocalCipherProvider();
        }
        else {
            lcp = new DefaultLocalCipherProvider();
        }
        
        return lcp;
    }
    
    
    @Provides @Singleton
    ServerSocketChannelFactory provideServerSocketChannelFactory() {
        return new NioServerSocketChannelFactory(
            Executors.newCachedThreadPool(
                new ThreadFactoryBuilder().setNameFormat(
                    "Lantern-Netty-Server-Boss-Thread-%d").setDaemon(true).build()),
            Executors.newCachedThreadPool(
                new ThreadFactoryBuilder().setNameFormat(
                    "Lantern-Netty-Server-Worker-Thread-%d").setDaemon(true).build()));
    }
    
    @Provides @Singleton
    ClientSocketChannelFactory provideClientSocketChannelFactory() {
        return new NioClientSocketChannelFactory(
            Executors.newCachedThreadPool(
                new ThreadFactoryBuilder().setNameFormat(
                    "Lantern-Netty-Client-Boss-Thread-%d").setDaemon(true).build()),
            Executors.newCachedThreadPool(
                new ThreadFactoryBuilder().setNameFormat(
                    "Lantern-Netty-Client-Worker-Thread-%d").setDaemon(true).build()));
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

    public void setEncryptedFileService(EncryptedFileService encryptedFileService) {
        this.encryptedFileService = encryptedFileService;
    }

    public void setLocalCipherProvider(LocalCipherProvider localCipherProvider) {
        this.localCipherProvider = localCipherProvider;
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
