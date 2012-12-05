package org.lantern;

import java.util.Timer;
import java.util.concurrent.Executors;

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
import org.lantern.http.GoogleOauth2RedirectServlet;
import org.lantern.http.InteractionServlet;
import org.lantern.http.JettyLauncher;
import org.lantern.http.LanternApi;
import org.lantern.privacy.DefaultLocalCipherProvider;
import org.lantern.privacy.LocalCipherProvider;
import org.lantern.privacy.MacLocalCipherProvider;
import org.lantern.privacy.WindowsLocalCipherProvider;
import org.lantern.state.CometDSyncStrategy;
import org.lantern.state.DefaultModelChangeImplementor;
import org.lantern.state.Model;
import org.lantern.state.ModelChangeImplementor;
import org.lantern.state.ModelIo;
import org.lantern.state.ModelUtils;
import org.lantern.state.SyncService;
import org.lantern.state.SyncStrategy;
import org.littleshoot.proxy.HttpRequestFilter;
import org.littleshoot.proxy.PublicIpsOnlyRequestFilter;

import com.google.common.util.concurrent.ThreadFactoryBuilder;
import com.google.inject.AbstractModule;
import com.google.inject.Provides;
import com.google.inject.Singleton;

public class LanternModule extends AbstractModule { 
    
    @Override 
    protected void configure() {
        // Tweak Netty naming...
        ThreadRenamingRunnable.setThreadNameDeterminer(
                ThreadNameDeterminer.CURRENT);
        
        bind(org.jboss.netty.util.Timer.class).to(HashedWheelTimer.class);
        //bind(LanternUtils.class);
        bind(ModelUtils.class);
        bind(HttpRequestFilter.class).to(PublicIpsOnlyRequestFilter.class);
        bind(Stats.class).to(StatsTracker.class);
        bind(LanternSocketsUtil.class);
        bind(LanternXmppUtil.class);
        bind(MessageService.class).to(Dashboard.class);
        bind(Proxifier.class);
        bind(Configurator.class);
        bind(SyncStrategy.class).to(CometDSyncStrategy.class);
        bind(SyncService.class);
        bind(EncryptedFileService.class).to(DefaultEncryptedFileService.class);
        bind(BrowserService.class).to(ChromeBrowserService.class);
        bind(Model.class).toProvider(ModelIo.class).in(Singleton.class);
        bind(ModelChangeImplementor.class).to(DefaultModelChangeImplementor.class);
        bind(InteractionServlet.class);
        bind(LanternKeyStoreManager.class);
        bind(SslHttpProxyServer.class);
        bind(PlainTestRelayHttpProxyServer.class);
        bind(XmppHandler.class).to(DefaultXmppHandler.class);
        bind(TrustedPeerProxyManager.class);
        bind(AnonymousPeerProxyManager.class);
        bind(GoogleOauth2RedirectServlet.class);
        bind(JettyLauncher.class);
        bind(AppIndicatorTray.class);
        bind(LanternApi.class).to(DefaultLanternApi.class);
        //bind(SettingsChangeImplementor.class).to(DefaultSettingsChangeImplementor.class);
        bind(LanternHttpProxyServer.class);
    }
    
    @Provides @Singleton
    SystemTray provideSystemTray(final BrowserService browserService) {
        if (SystemUtils.IS_OS_LINUX) {
            return new AppIndicatorTray(browserService);
        } else {
            return new SystemTrayImpl(browserService);
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
    LocalCipherProvider provideLocalCipher() {
        final LocalCipherProvider lcp; 
        
        /*
        if (!settings().isKeychainEnabled()) {
            lcp = new DefaultLocalCipherProvider();
        }
        */
        if (SystemUtils.IS_OS_WINDOWS) {
            lcp = new WindowsLocalCipherProvider();   
        }
        else if (SystemUtils.IS_OS_MAC_OSX) {
            lcp = new MacLocalCipherProvider();
        }
        // disabled per #249
        //else if (SystemUtils.IS_OS_LINUX && 
        //         SecretServiceLocalCipherProvider.secretServiceAvailable()) {
        //    lcp = new SecretServiceLocalCipherProvider();
        //}
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
}
