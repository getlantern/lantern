package org.lantern.kscope;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.lantern.LanternTrustStore;
import org.lantern.ProxyTracker;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class DefaultKscopeAdHandler implements KscopeAdHandler {

    private final Map<String, LanternKscopeAdvertisement> awaitingCerts = 
        new ConcurrentHashMap<String, LanternKscopeAdvertisement>();
    private final ProxyTracker proxyTracker;
    private final LanternTrustStore trustStore;
    
    @Inject
    public DefaultKscopeAdHandler(final ProxyTracker proxyTracker,
        final LanternTrustStore trustStore) {
        this.proxyTracker = proxyTracker;
        this.trustStore = trustStore;
    }
    
    @Override
    public void handleAd(final LanternKscopeAdvertisement ad) {
        awaitingCerts.put(ad.getJid(), ad);
    }
    
    @Override
    public void onBase64Cert(final String uri, final String base64Cert) {
        try {
            this.trustStore.addBase64Cert(uri, base64Cert);
        } catch (IOException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
        //this.proxyTracker.
        //trustedPeerProxyManager.onPeer(uri, base64Cert);
    }

}
