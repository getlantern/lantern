package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.security.SecureRandom;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import java.util.zip.GZIPInputStream;

import org.apache.commons.io.IOUtils;
import org.eclipse.swt.widgets.Display;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.maxmind.geoip.LookupService;

/**
 * Class for accessing all of the core modules used in Lantern.
 */
public class LanternHub {

    private static final Logger LOG = LoggerFactory.getLogger(LanternHub.class);
    private volatile static TrustedContactsManager trustedContactsManager;
    private volatile static Display display;
    private volatile static SystemTray systemTray;
    
    private volatile static StatsTracker statsTracker;
    private volatile static LanternKeyStoreManager proxyKeyStore;
    
    private volatile static XmppHandler xmppHandler;
    private volatile static int randomSslPort = -1;
    
    private volatile static LookupService lookupService;
    
    private static final AtomicReference<JettyLauncher> jettyLauncher =
        new AtomicReference<JettyLauncher>();
    
    
    private static final AtomicReference<PeerProxyManager> trustedPeerProxyManager =
        new AtomicReference<PeerProxyManager>();
    
    private static final AtomicReference<PeerProxyManager> anonymousPeerProxyManager =
        new AtomicReference<PeerProxyManager>();
    
    private static final AtomicReference<SecureRandom> secureRandom =
        new AtomicReference<SecureRandom>();
    
    private static final File UNZIPPED = 
        new File(LanternUtils.dataDir(), "GeoIP.dat");
    
    public synchronized static LookupService getGeoIpLookup() {
        if (lookupService == null) {
            lookupService = buildLookupService();
        }
        return lookupService;
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
            lookupService = new LookupService(UNZIPPED, 
                    LookupService.GEOIP_MEMORY_CACHE);
        } catch (final IOException e) {
            LOG.error("Could not create LOOKUP service?");
            lookupService = null;
        }
        return lookupService;
    }

    public synchronized static TrustedContactsManager getTrustedContactsManager() {
        if (trustedContactsManager == null) {
            trustedContactsManager = new DefaultTrustedContactsManager();
        } 
        return trustedContactsManager;
    }

    public synchronized static Display display() {
        if (display == null) {
            display = new Display();
        }
        return display;
    }

    public synchronized static SystemTray systemTray() {
        if (systemTray == null) {
            if (LanternUtils.runWithUi()) {
                systemTray = new SystemTrayImpl(display());
                systemTray.createTray();
            } else {
                return new SystemTray() {
                    @Override
                    public void createTray() {}
                    @Override
                    public void activate() {}
                    @Override
                    public void addUpdate(Map<String, String> updateData) {}
                };
            }
        }
        return systemTray;
    }

    public synchronized static StatsTracker statsTracker() {
        if (statsTracker == null) {
            statsTracker = new StatsTracker();
        }
        return statsTracker;
    }

    public synchronized static LanternKeyStoreManager getKeyStoreManager() {
        if (proxyKeyStore == null) {
            proxyKeyStore = new LanternKeyStoreManager(true);
        }
        return proxyKeyStore;
    }

    public synchronized static XmppHandler xmppHandler() {
        if (xmppHandler == null) {
            xmppHandler = new XmppHandler(randomSslPort(), 
                LanternConstants.PLAINTEXT_LOCALHOST_PROXY_PORT);
        }
        return xmppHandler;
    }

    public synchronized static int randomSslPort() {
        if (randomSslPort == -1) {
            randomSslPort = LanternUtils.randomPort();
        }
        return randomSslPort;
    }

    public static JettyLauncher jettyLauncher() {
        if (jettyLauncher.get() == null) {
            final JettyLauncher jl = new JettyLauncher();
            jl.start();
            jettyLauncher.set(jl);
        }
        return jettyLauncher.get();
    }

    public static PeerProxyManager trustedPeerProxyManager() {
        if (trustedPeerProxyManager.get() == null) {
            final PeerProxyManager eppl =
                new DefaultPeerProxyManager(false);
            trustedPeerProxyManager.set(eppl);
        }
        return trustedPeerProxyManager.get();
    }
    
    public static PeerProxyManager anonymousPeerProxyManager() {
        if (anonymousPeerProxyManager.get() == null) {
            final PeerProxyManager eppl =
                new DefaultPeerProxyManager(true);
            anonymousPeerProxyManager.set(eppl);
        }
        return anonymousPeerProxyManager.get();
    }

    public static SecureRandom secureRandom() {
        if (secureRandom.get() == null) {
            secureRandom.set(new SecureRandom());
        }
        return secureRandom.get();
    }

}
