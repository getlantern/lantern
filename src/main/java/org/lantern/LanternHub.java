package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.security.SecureRandom;
import java.util.Map;
import java.util.Timer;
import java.util.concurrent.atomic.AtomicReference;
import java.util.zip.GZIPInputStream;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.SystemUtils;
import org.eclipse.swt.widgets.Display;
import org.lantern.cookie.CookieTracker;
import org.lantern.cookie.InMemoryCookieTracker;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.EventBus;
import com.maxmind.geoip.LookupService;

/**
 * Class for accessing all of the core modules used in Lantern.
 */
public class LanternHub {

    private static final Logger LOG = LoggerFactory.getLogger(LanternHub.class);
    
    private static final AtomicReference<EventBus> eventBus =
        new AtomicReference<EventBus>(new EventBus());
    
    private static final File UNZIPPED = 
        new File(LanternUtils.dataDir(), "GeoIP.dat");
    
    private volatile static AtomicReference<TrustedContactsManager> trustedContactsManager =
        new AtomicReference<TrustedContactsManager>();
    private volatile static AtomicReference<Display> display = 
        new AtomicReference<Display>();
    private volatile static AtomicReference<SystemTray> systemTray = 
        new AtomicReference<SystemTray>();
    
    private volatile static AtomicReference<StatsTracker> statsTracker = 
        new AtomicReference<StatsTracker>();
    private volatile static AtomicReference<LanternKeyStoreManager> proxyKeyStore = 
        new AtomicReference<LanternKeyStoreManager>();
    
    private volatile static AtomicReference<XmppHandler> xmppHandler = 
        new AtomicReference<XmppHandler>();
    private volatile static AtomicReference<Integer> randomSslPort = 
        new AtomicReference<Integer>(-1);
    
    private volatile static AtomicReference<LookupService> lookupService = 
        new AtomicReference<LookupService>();
    
    private static final AtomicReference<JettyLauncher> jettyLauncher =
        new AtomicReference<JettyLauncher>();
    
    
    private static final AtomicReference<PeerProxyManager> trustedPeerProxyManager =
        new AtomicReference<PeerProxyManager>();
    
    private static final AtomicReference<PeerProxyManager> anonymousPeerProxyManager =
        new AtomicReference<PeerProxyManager>();
    
    private static final AtomicReference<SecureRandom> secureRandom =
        new AtomicReference<SecureRandom>();

    private static final AtomicReference<CookieTracker> cookieTracker =
        new AtomicReference<CookieTracker>();

    private static final AtomicReference<LocalCipherProvider> localCipherProvider =
        new AtomicReference<LocalCipherProvider>();
    
    private static final AtomicReference<Censored> censored =
        new AtomicReference<Censored>();
    
    private static final AtomicReference<Timer> timer =
        new AtomicReference<Timer>();
        
    private static final AtomicReference<SettingsIo> settingsIo =
        new AtomicReference<SettingsIo>();
    
    private static final AtomicReference<LanternApi> lanternApi =
        new AtomicReference<LanternApi>();
    
    private static  Settings settings;
    
    static {
        final SettingsIo io = LanternHub.settingsIo();
        LOG.info("Setting settings...");
        try {
            settings = io.read();
        } catch (final Throwable t) {
            LOG.error("Caught throwable: {}", t);
        }
        
        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {

            @Override
            public void run() {
                LOG.info("Writing settings");
                io.write(settings);
                LOG.info("Finished writing settings...");
            }
            
        }, "Write-Settings-Thread"));
        
        // We need the system tray to listen for events early on.
        systemTray();
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

    public static SystemTray systemTray() {
        synchronized (systemTray) {
            if (systemTray.get() == null) {
                if (LanternUtils.runWithUi()) {
                    final SystemTray tray = new SystemTrayImpl(display());
                    tray.createTray();
                    systemTray.set(tray);
                } else {
                    return new SystemTray() {
                        @Override
                        public void createTray() {}
                        @Override
                        public void addUpdate(Map<String, String> updateData) {}
                    };
                }
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
        synchronized (proxyKeyStore) {
            if (proxyKeyStore.get() == null) {
                proxyKeyStore.set(new LanternKeyStoreManager());
            }
            return proxyKeyStore.get();
        }
    }

    public static XmppHandler xmppHandler() {
        synchronized (xmppHandler) {
            if (xmppHandler.get() == null) {
                xmppHandler.set(new XmppHandler(randomSslPort(), 
                    LanternConstants.PLAINTEXT_LOCALHOST_PROXY_PORT));
            }
            return xmppHandler.get();
        }
    }

    public static int randomSslPort() {
        synchronized (randomSslPort) {
            if (randomSslPort.get() == -1) {
                randomSslPort.set(LanternUtils.randomPort());
            }
            return randomSslPort.get();
        }
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
                final PeerProxyManager eppl =
                    new DefaultPeerProxyManager(false);
                trustedPeerProxyManager.set(eppl);
            }
            return trustedPeerProxyManager.get();
        }
    }
    
    public static PeerProxyManager anonymousPeerProxyManager() {
        synchronized (anonymousPeerProxyManager) {
            if (anonymousPeerProxyManager.get() == null) {
                final PeerProxyManager eppl =
                    new DefaultPeerProxyManager(true);
                anonymousPeerProxyManager.set(eppl);
            }
            return anonymousPeerProxyManager.get();
        }
    }

    public static SecureRandom secureRandom() {
        synchronized (secureRandom) {
            if (secureRandom.get() == null) {
                secureRandom.set(new SecureRandom());
            }
            return secureRandom.get();
        }
    }

    public static CookieTracker cookieTracker() {
        synchronized (cookieTracker) {
            if (cookieTracker.get() == null) {
                cookieTracker.set(new InMemoryCookieTracker());
            }
            return cookieTracker.get();
        }
    }
    
    public static LocalCipherProvider localCipherProvider() {
        synchronized(localCipherProvider) {
            if (localCipherProvider.get() == null) {

                if (SystemUtils.IS_OS_WINDOWS) {
                    localCipherProvider.set(new WindowsLocalCipherProvider());   
                }
                else if (SystemUtils.IS_OS_MAC_OSX) {
                    localCipherProvider.set(new MacLocalCipherProvider());
                }
                else if (SystemUtils.IS_OS_LINUX && 
                         SecretServiceLocalCipherProvider.secretServiceAvailable()) {
                    localCipherProvider.set(new SecretServiceLocalCipherProvider());                
                }
                else {
                    localCipherProvider.set(new DefaultLocalCipherProvider());
                }
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
                timer.set(new Timer());
            }
            return timer.get();
        }
    }

   
    public static Whitelist whitelist() {
        return settings.getWhitelist();
    }
    
    public static UserInfo userInfo() {
        return settings.getUser();
    }
    
    public static SystemInfo systemInfo() {
        return settings.getSystem();
    }

    public static Platform platform() {
        return settings.getSystem().getPlatform();
    }
    
    public static Internet internet() {
        return settings.getSystem().getInternet();
    }
    
    public static Roster roster() {
        return settings.getRoster();
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
        return settings;
    }
    
    public static EventBus eventBus() {
        return eventBus.get();
    }

    public static LanternApi api() {
        synchronized (lanternApi) {
            if (lanternApi.get() == null) {
                lanternApi.set(new DefaultLanternApi());
            }
            return lanternApi.get();
        }
    }
}
