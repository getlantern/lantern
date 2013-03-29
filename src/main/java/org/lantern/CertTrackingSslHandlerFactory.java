package org.lantern;

import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;

import javax.net.ssl.SSLEngine;
import javax.net.ssl.TrustManager;

import org.jboss.netty.handler.ssl.SslHandler;
import org.littleshoot.proxy.HandshakeHandler;
import org.littleshoot.proxy.HandshakeHandlerFactory;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.proxy.SslContextFactory;
import org.littleshoot.proxy.SslHandshakeHandler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class CertTrackingSslHandlerFactory implements HandshakeHandlerFactory {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final KeyStoreManager ksm;
    private final LanternTrustStore trustStore;
    
    @Inject
    public CertTrackingSslHandlerFactory(final KeyStoreManager ksm, 
        final LanternTrustStore trustStore) {
        this.ksm = ksm;
        this.trustStore = trustStore;
    }

    /**
     * This method is called for every new pipeline that's created -- i.e.
     * for every new incoming connection to the server. We need to reload
     * the trust store each to make sure we take into account all the last
     * certificates from peers.
     */
    @Override
    public HandshakeHandler newHandshakeHandler() {
        final TrustManager[] trustManagers = new TrustManager[]{new CertTrackingTrustManager()};
        final SslContextFactory scf = new SslContextFactory(ksm, trustManagers);
        final SSLEngine engine = scf.getServerContext().createSSLEngine();
        engine.setUseClientMode(false);
        engine.setNeedClientAuth(true);
        final SslHandler handler = new SslHandler(engine);
        return new SslHandshakeHandler("ssl", handler);
    }
    
    private final class CertTrackingTrustManager implements javax.net.ssl.X509TrustManager {

        @Override
        public void checkClientTrusted(final X509Certificate[] chain, String arg1)
                throws CertificateException {
            final X509Certificate cert = chain[0];
            if (!trustStore.containsCertificate(cert)) {
                throw new CertificateException("not trusted");
            }
            log.debug("Certificate trusted");
        }

        @Override
        public void checkServerTrusted(X509Certificate[] arg0, String arg1)
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
}
