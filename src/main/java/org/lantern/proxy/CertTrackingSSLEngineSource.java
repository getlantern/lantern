package org.lantern.proxy;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.security.KeyStore;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLEngine;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

import org.lantern.LanternKeyStoreManager;
import org.lantern.LanternTrustStore;
import org.lantern.LanternUtils;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.littleshoot.proxy.SSLEngineSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * This {@link SSLEngineSource} creates {@link SSLEngine}s that authenticates
 * peers based on their client certificates and only allows trusted peers.
 */
@Singleton
public class CertTrackingSSLEngineSource implements SSLEngineSource {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final LanternTrustStore trustStore;
    private final LanternKeyStoreManager keyStoreManager;

    @Inject
    public CertTrackingSSLEngineSource(
            final LanternTrustStore trustStore,
            final LanternKeyStoreManager keyStoreManager) {
        this.trustStore = trustStore;
        this.keyStoreManager = keyStoreManager;
    }

    @Override
    public SSLEngine newSSLEngine() {
        if (LanternUtils.isFallbackProxy()) {
            return fallbackProxySslEngine();
        } else {
            return standardSslEngine(new CertTrackingTrustManager());
        }
    }

    private SSLEngine fallbackProxySslEngine() {
        log.debug("Using fallback proxy context");
        final String PASS = "Be Your Own Lantern";
        try {
            final KeyStore ks = KeyStore.getInstance("JKS");

            final File keystore = new File(LanternUtils.getKeystorePath());
            final InputStream is = new FileInputStream(keystore);
            ks.load(is, PASS.toCharArray());

            // Set up key manager factory to use our key store
            final KeyManagerFactory kmf =
                    KeyManagerFactory.getInstance("SunX509");
            kmf.init(ks, PASS.toCharArray());

            // Initialize the SSLContext to work with our key managers.
            final SSLContext serverContext = SSLContext.getInstance("TLS");

            // NO CLIENT AUTH!!
            serverContext.init(kmf.getKeyManagers(), null, null);
            final SSLEngine engine = serverContext.createSSLEngine();
            engine.setUseClientMode(false);
            return engine;
        } catch (final Exception e) {
            throw new Error(
                    "Failed to initialize the server-side SSLContext", e);
        }
    }

    private SSLEngine standardSslEngine(
            final CertTrackingTrustManager trustManager) {
        log.debug("Using standard SSL context");
        try {
            final SSLContext context = SSLContext.getInstance("TLS");
            context.init(this.keyStoreManager.getKeyManagerFactory()
                    .getKeyManagers(),
                    new TrustManager[] { trustManager }, null);
            final SSLEngine engine = context.createSSLEngine();
            engine.setUseClientMode(false);
            engine.setNeedClientAuth(true);
            final String[] suites = IceConfig.getCipherSuites();
            if (suites != null && suites.length > 0) {
                engine.setEnabledCipherSuites(suites);
            } else {
                // Can be null in tests.
                log.warn("No cipher suites?");
            }
            return engine;
        } catch (final Exception e) {
            throw new Error(
                    "Failed to initialize the client-side SSLContext", e);
        }
    }

    private class CertTrackingTrustManager implements X509TrustManager {

        private final Logger loggger = LoggerFactory.getLogger(getClass());

        @Override
        public void checkClientTrusted(final X509Certificate[] chain,
                String arg1)
                throws CertificateException {
            loggger.debug("Checking client trusted...");
            final X509Certificate cert = chain[0];
            if (!LanternUtils.isFallbackProxy() &&
                    !trustStore.containsCertificate(cert)) {
                loggger.warn("Certificate is not trusted!!");
                throw new CertificateException("not trusted");
            }

            loggger.debug("Certificate trusted");
        }

        @Override
        public void checkServerTrusted(final X509Certificate[] chain,
                String arg1)
                throws CertificateException {
            throw new CertificateException(
                    "Should never be checking server trust from the server");
        }

        @Override
        public X509Certificate[] getAcceptedIssuers() {
            // We don't accept any issuers.
            return new X509Certificate[] {};
        }
    }
}
