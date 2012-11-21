package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.security.SecureRandom;
import java.util.Timer;
import java.util.concurrent.atomic.AtomicReference;
import java.util.zip.GZIPInputStream;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.SystemUtils;
import org.eclipse.swt.widgets.Display;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.ServerSocketChannelFactory;
import org.lantern.cookie.CookieTracker;
import org.lantern.cookie.InMemoryCookieTracker;
import org.lantern.event.SettingsStateEvent;
import org.lantern.http.JettyLauncher;
import org.lantern.http.LanternApi;
import org.lantern.httpseverywhere.HttpsEverywhere;
import org.lantern.privacy.DefaultLocalCipherProvider;
import org.lantern.privacy.LocalCipherProvider;
import org.lantern.privacy.MacLocalCipherProvider;
import org.lantern.privacy.WindowsLocalCipherProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.maxmind.geoip.LookupService;

/**
 * Class for accessing all of the core modules used in Lantern.
 */
public class LanternHub {

    private static final Logger LOG = LoggerFactory.getLogger(LanternHub.class);
    
    private static final AtomicReference<SecureRandom> secureRandom =
        new AtomicReference<SecureRandom>(new SecureRandom());
    
    private static final File UNZIPPED = 
        new File(LanternConstants.DATA_DIR, "GeoIP.dat");
    
    private static final AtomicReference<TrustedContactsManager> trustedContactsManager =
        new AtomicReference<TrustedContactsManager>();
    private static final AtomicReference<Display> display = 
        new AtomicReference<Display>();
    private static final AtomicReference<SystemTray> systemTray = 
        new AtomicReference<SystemTray>();
    
    private static final AtomicReference<StatsTracker> statsTracker = 
        new AtomicReference<StatsTracker>();
    private static LanternKeyStoreManager proxyKeyStore;
    
    static {
        if (!LanternConstants.ON_APP_ENGINE) {
            proxyKeyStore = new LanternKeyStoreManager();
        } else {
            proxyKeyStore = null;
        }
    }
        
    
    private static final AtomicReference<XmppHandler> xmppHandler = 
        new AtomicReference<XmppHandler>();
    
    private static final AtomicReference<ProxyProvider> proxyProvider =
        new AtomicReference<ProxyProvider>();
    
    private static final AtomicReference<ProxyStatusListener> proxyStatusListener =
        new AtomicReference<ProxyStatusListener>();
    
    private static final AtomicReference<SettingsChangeImplementor> settingsChangeImplementor =
        new AtomicReference<SettingsChangeImplementor>(new DefaultSettingsChangeImplementor());

    private static final AtomicReference<Timer> timer =
        new AtomicReference<Timer>();
    
    private static final AtomicReference<LookupService> lookupService = 
        new AtomicReference<LookupService>();
    
    private static final AtomicReference<JettyLauncher> jettyLauncher =
        new AtomicReference<JettyLauncher>();
    
    
    private static final AtomicReference<PeerProxyManager> trustedPeerProxyManager =
        new AtomicReference<PeerProxyManager>();
    
    private static final AtomicReference<PeerProxyManager> anonymousPeerProxyManager =
        new AtomicReference<PeerProxyManager>();

    private static final AtomicReference<CookieTracker> cookieTracker =
        new AtomicReference<CookieTracker>();

    private static final AtomicReference<LocalCipherProvider> localCipherProvider =
        new AtomicReference<LocalCipherProvider>();
    
    private static final AtomicReference<Censored> censored =
        new AtomicReference<Censored>();
    
    private static final AtomicReference<SettingsIo> settingsIo =
        new AtomicReference<SettingsIo>();
    
    private static final AtomicReference<LanternApi> lanternApi =
        new AtomicReference<LanternApi>();
    
    private static final AtomicReference<Dashboard> dashboard =
        new AtomicReference<Dashboard>();
    
    private static final AtomicReference<HttpsEverywhere> httpsEverywhere =
        new AtomicReference<HttpsEverywhere>();
    
    private static final AtomicReference<Settings> settings = 
        new AtomicReference<Settings>();
    
    private static final Configurator configurator = new Configurator();

    private static org.jboss.netty.util.Timer nettyTimer;
    
    private static ServerSocketChannelFactory serverChannelFactory;
    
    private static ClientSocketChannelFactory clientChannelFactory;
    
    private static ChannelGroup channelGroup;
    
    static {
        // start with an UNSET settings object until loaded
        settings.set(new Settings());
        postSettingsState();
        
        if (!LanternConstants.ON_APP_ENGINE) {
            // if they were successfully loaded, save the most current state when exiting.
            Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
    
                @Override
                public void run() {
                    SettingsState ss = settings().getSettings();
                    if (ss.getState() == SettingsState.State.SET) {
                        LOG.info("Writing settings");
                        LanternHub.settingsIo().write(LanternHub.settings());
                        LOG.info("Finished writing settings...");
                    }
                    else {
                        LOG.warn("Not writing settings, state was {}", ss.getState());
                    }
                }
                
            }, "Write-Settings-Thread"));
        }
    }
    
    public static LookupService getGeoIpLookup() {
        synchronized (lookupService) {
            if (lookupService.get() == null) {
                lookupService.set(buildLookupService());
            }
            return lookupService.get();
        }
    }
    
    private static LookupService buildLookupService() {
        if (!UNZIPPED.isFile())  {
            final File file = new File("GeoIP.dat.gz");
            GZIPInputStream is = null;
            OutputStream os = null;
            try {
                is = new GZIPInputStream(new FileInputStream(file));
                os = new FileOutputStream(UNZIPPED);
                IOUtils.copy(is, os);
            } catch (final IOException e) {
                LOG.error("Error expanding file?", e);
            } finally {
                IOUtils.closeQuietly(is);
                IOUtils.closeQuietly(os);
            }
        }
        try {
            return new LookupService(UNZIPPED, 
                    LookupService.GEOIP_MEMORY_CACHE);
        } catch (final IOException e) {
            LOG.error("Could not create LOOKUP service?");
        }
        return null;
    }

    public static TrustedContactsManager getTrustedContactsManager() {
        synchronized (trustedContactsManager) {
            if (trustedContactsManager.get() == null) {
                trustedContactsManager.set(new DefaultTrustedContactsManager());
            } 
            return trustedContactsManager.get();
        }
    }
    
    public static Display display() {
        synchronized (display) {
            if (display.get() == null) {
                display.set(new Display());
            }
            return display.get();
        }
    }
    

    public static void resetDisplay() {
        synchronized (display) {
            display.set(null);
        }
    }

    public static SystemTray systemTray() {
        synchronized (systemTray) {
            if (systemTray.get() == null) {
                systemTray.set(new FallbackTray());
            }
            return systemTray.get();
        }
    }

    public static StatsTracker statsTracker() {
        synchronized (statsTracker) {
            if (statsTracker.get() == null) {
                statsTracker.set(new StatsTracker());
            }
            return statsTracker.get();
        }
    }
    
    public static LanternKeyStoreManager getKeyStoreManager() {
        return proxyKeyStore;
    }

    
    public static void setKeyStoreManager(final LanternKeyStoreManager lksm) {
        proxyKeyStore = lksm;
    }
    
    public static XmppHandler xmppHandler() {
        synchronized (xmppHandler) {
            if (xmppHandler.get() == null) {
                xmppHandler.set(new DefaultXmppHandler());
            }
            return xmppHandler.get();
        }
    }
    
    public static void setXmppHandler(final XmppHandler xmpp) {
        xmppHandler.set(xmpp);
    }

    public static JettyLauncher jettyLauncher() {
        synchronized (jettyLauncher) {
            if (jettyLauncher.get() == null) {
                final JettyLauncher jl = new JettyLauncher();
                jl.start();
                jettyLauncher.set(jl);
            }
            return jettyLauncher.get();
        }
    }

    public static PeerProxyManager trustedPeerProxyManager() {
        synchronized (trustedPeerProxyManager) {
            if (trustedPeerProxyManager.get() == null) {
                trustedPeerProxyManager.set(
                    new DefaultPeerProxyManager(false, channelGroup));
            }
            return trustedPeerProxyManager.get();
        }
    }
    
    private static void resetTrustedPeerProxyManager() {
        // Close all existing p2p connections.
        if (trustedPeerProxyManager.get() != null) {
            trustedPeerProxyManager.get().closeAll();
        }
    }
    
    public static PeerProxyManager anonymousPeerProxyManager() {
        synchronized (anonymousPeerProxyManager) {
            if (anonymousPeerProxyManager.get() == null) {
                anonymousPeerProxyManager.set(
                    new DefaultPeerProxyManager(true, channelGroup));
            }
            return anonymousPeerProxyManager.get();
        }
    }

    public static SecureRandom secureRandom() {
        return secureRandom.get();
    }

    public static CookieTracker cookieTracker() {
        synchronized (cookieTracker) {
            if (cookieTracker.get() == null) {
                resetCookieTracker();
            }
            return cookieTracker.get();
        }
    }
    
    protected static void resetCookieTracker() {
        cookieTracker.set(new InMemoryCookieTracker());
    }
    
    public static LocalCipherProvider localCipherProvider() {
        synchronized(localCipherProvider) {
            if (localCipherProvider.get() == null) {
                final LocalCipherProvider lcp; 
                
                if (!settings().isKeychainEnabled()) {
                    lcp = new DefaultLocalCipherProvider();
                }
                else if (SystemUtils.IS_OS_WINDOWS) {
                    lcp = new WindowsLocalCipherProvider();   
                }
                else if (SystemUtils.IS_OS_MAC_OSX) {
                    lcp = new MacLocalCipherProvider();
                }
                /* disabled per #249
                else if (SystemUtils.IS_OS_LINUX && 
                         SecretServiceLocalCipherProvider.secretServiceAvailable()) {
                    lcp = new SecretServiceLocalCipherProvider();
                }
                */
                else {
                    lcp = new DefaultLocalCipherProvider();
                }
                
                localCipherProvider.set(lcp);
            }
            return localCipherProvider.get();
        }
    }
    
    public static Censored censored() {
        synchronized (censored) {
            if (censored.get() == null) {
                censored.set(new DefaultCensored());
            }
            return censored.get();
        }
    }

    public static Timer timer() {
        synchronized (timer) {
            if (timer.get() == null) {
                timer.set(new Timer("Lantern-Timer", true));
            }
            return timer.get();
        }
    }


    public static void setNettyTimer(final org.jboss.netty.util.Timer timer) {
        nettyTimer = timer;
    }
    
    public static org.jboss.netty.util.Timer getNettyTimer() {
        return nettyTimer;
    }

    public static ChannelGroup getChannelGroup() {
        return channelGroup;
    }

    public static void setChannelGroup(final ChannelGroup channelGroup) {
        LanternHub.channelGroup = channelGroup;
    }
    
    public static ServerSocketChannelFactory getServerChannelFactory() {
        return serverChannelFactory;
    }

    public static void setServerChannelFactory(
        final ServerSocketChannelFactory serverChannelFactory) {
        LanternHub.serverChannelFactory = serverChannelFactory;
    }

    public static ClientSocketChannelFactory getClientChannelFactory() {
        return clientChannelFactory;
    }

    public static void setClientChannelFactory(
        final ClientSocketChannelFactory clientChannelFactory) {
        LanternHub.clientChannelFactory = clientChannelFactory;
    }
    
    public static Whitelist whitelist() {
        return settings().getWhitelist();
    }
    
    public static Platform platform() {
        return settings().getPlatform();
    }
    
    public static SettingsIo settingsIo() {
        synchronized (settingsIo) {
            if (settingsIo.get() == null) {
                final SettingsIo io = new SettingsIo();
                settingsIo.set(io);
            }
            return settingsIo.get();
        }
    }
    
    public static Settings settings() {
        return settings.get();
    }

    public static LanternApi api() {
        synchronized (lanternApi) {
            if (lanternApi.get() == null) {
                lanternApi.set(new DefaultLanternApi());
            }
            return lanternApi.get();
        }
    }
    
    public static Dashboard dashboard() {
        synchronized (dashboard) {
            if (dashboard.get() == null) {
                dashboard.set(new Dashboard());
            }
            return dashboard.get();
        }
    }
    
    public static LanternTrustManager trustManager() {
        return LanternHub.getKeyStoreManager().getTrustManager();
    }

    public static void resetSettings(boolean retainCLIOptions) {
        final Settings old = settings.get();
        final SettingsIo io = LanternHub.settingsIo();
        LOG.info("Setting settings...");
        try {
            settings.set(io.read());
        } catch (final Throwable t) {
            LOG.error("Caught throwable resetting settings: {}", t);
        }
       
        // retain any CommandLineSettings to the newly loaded settings
        // if requested.
        final Settings cur = settings();
        if (retainCLIOptions == true && cur != null && old != null) {
            try {
                old.copyCLI(cur);
            }
            catch (final Throwable t) {
                LOG.error("error copying command line settings! {}", t);
            }
        }
        
        postSettingsState();
    }
   
    private static void postSettingsState() {
        Events.asyncEventBus().post(new SettingsStateEvent(settings().getSettings()));
    }
    
    public static ProxyProvider getProxyProvider() {
        synchronized (proxyProvider) {
            if (proxyProvider.get() == null) {
                proxyProvider.set(xmppHandler());
            }
            return proxyProvider.get();
        }
    }
    
    public static void setProxyProvider(final ProxyProvider pp) {
        proxyProvider.set(pp);
    }
    
    public static ProxyStatusListener getProxyStatusListener() {
        synchronized (proxyStatusListener) {
            if (proxyStatusListener.get() == null) {
                proxyStatusListener.set(xmppHandler());
            }
            return proxyStatusListener.get();
        }
    }
    
    public static void setProxyStatusListener(final ProxyStatusListener pp) {
        proxyStatusListener.set(pp);
    }
    
    public static SettingsChangeImplementor settingsChangeImplementor() {
        return settingsChangeImplementor.get();
    }
    
    public static void setSettingsChangeImplementor(
        final SettingsChangeImplementor ssi) {
        settingsChangeImplementor.set(ssi);
    }
    
    public static Configurator configurator() {
        return configurator;
    }

    public static HttpsEverywhere httpsEverywhere() {
        synchronized (httpsEverywhere) {
            if (httpsEverywhere.get() == null) {
                httpsEverywhere.set(new HttpsEverywhere());
            }
            return httpsEverywhere.get();
        }
    }
    
    public static void resetUserConfig() {
        // resets user specific configuration.
        final Settings set = settings();
        set.setEmail("");
        set.setPassword("");
        set.setStoredPassword("");
        set.setPasswordSaved(false);
        set.getTransfers().setDownTotalLifetime(0);
        set.getTransfers().setUpTotalLifetime(0);

        TrustedContactsManager tcm = trustedContactsManager.get();
        if (tcm != null) {
            tcm.clearTrustedContacts();
        }
        xmppHandler().resetRoster();
        resetTrustedPeerProxyManager();
        resetCookieTracker();
        statsTracker().resetUserStats();
    }
    
    /**
     * This should do whatever is necessary to reset back to 'factory' defaults. 
     */
    public static void destructiveFullReset() throws IOException {
        LanternHub.localCipherProvider().reset();
        if (LanternConstants.DEFAULT_SETTINGS_FILE.isFile()) {
            FileUtils.forceDelete(LanternConstants.DEFAULT_SETTINGS_FILE);
        }
        LanternHub.resetSettings(true); // does not affect command line though...
        LanternHub.resetUserConfig(); // among others, TrustedContacts...
    }
}
