package org.lantern;

import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;

import javax.net.ssl.X509TrustManager;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class CertTrackingTrustManager implements X509TrustManager {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final LanternTrustStore trustStore;
    
    public CertTrackingTrustManager(final LanternTrustStore trustStore) {
        this.trustStore = trustStore;
    }
    
    @Override
    public void checkClientTrusted(final X509Certificate[] chain, String arg1)
            throws CertificateException {
        final X509Certificate cert = chain[0];
        if (!trustStore.containsCertificate(cert)) {
            throw new CertificateException("not trusted");
        }
        
        // We should already know about the peer at this point, and it's just
        // a matter of correlating that peer with this certificate and 
        // connection.
        log.debug("Certificate trusted");
    }

    @Override
    public void checkServerTrusted(final X509Certificate[] chain, String arg1)
            throws CertificateException {
        throw new CertificateException(
                "Should never be checking server trust from the server");
    }

    @Override
    public X509Certificate[] getAcceptedIssuers() {
        // We don't accept any issuers.
        return new X509Certificate[]{};
    }
}
