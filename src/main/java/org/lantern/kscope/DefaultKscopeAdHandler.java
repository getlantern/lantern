package org.lantern.kscope;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.kaleidoscope.RandomRoutingTable;
import org.lantern.LanternTrustStore;
import org.lantern.ProxyTracker;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class DefaultKscopeAdHandler implements KscopeAdHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    /**
     * Map of kscope advertisements for which we are awaiting corresponding
     * certificates.
     */
    private final Map<String, LanternKscopeAdvertisement> awaitingCerts = 
        new ConcurrentHashMap<String, LanternKscopeAdvertisement>();
    private final ProxyTracker proxyTracker;
    private final LanternTrustStore trustStore;
    private final RandomRoutingTable routingTable;
    
    @Inject
    public DefaultKscopeAdHandler(final ProxyTracker proxyTracker,
        final LanternTrustStore trustStore,
        final RandomRoutingTable routingTable) {
        this.proxyTracker = proxyTracker;
        this.trustStore = trustStore;
        this.routingTable = routingTable;
    }
    
    @Override
    public void handleAd(final LanternKscopeAdvertisement ad) {
        awaitingCerts.put(ad.getJid(), ad);
    }
    
    @Override
    public void onBase64Cert(final String jid, final String base64Cert) {
        try {
            this.trustStore.addBase64Cert(jid, base64Cert);
        } catch (final IOException e) {
            log.error("Could not add cert?", e);
        }
        
        final LanternKscopeAdvertisement ad = awaitingCerts.get(jid);
        if (ad != null) {
            if (ad.hasMappedEndpoint()) {
                this.proxyTracker.addProxy(
                    InetSocketAddress.createUnresolved(ad.getAddress(), ad.getPort()));
            } else {
                this.proxyTracker.addJidProxy(ad.getJid());
            }
        } else {
            // This could happen if we negotiated certs in some way other than
            // in response to a kscope ad, such as for peers from the 
            // controller.
            log.info("No ad for cert?");
            this.proxyTracker.addJidProxy(jid);
        }
    }

}
