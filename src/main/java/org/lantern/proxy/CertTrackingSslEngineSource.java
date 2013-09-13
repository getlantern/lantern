package org.lantern.proxy;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.KeyManagementException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLEngine;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

import org.apache.commons.io.IOUtils;
import org.lantern.LanternKeyStoreManager;
import org.lantern.LanternTrustStore;
import org.lantern.LanternUtils;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.littleshoot.proxy.SslEngineSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * This {@link SslEngineSource} creates {@link SSLEngine}s that authenticates
 * peers based on their client certificates and only allows trusted peers.
 */
@Singleton
public class CertTrackingSslEngineSource implements SslEngineSource {
    private static final Logger LOG = LoggerFactory.getLogger(CertTrackingSslEngineSource.class);
    
    private final LanternTrustStore trustStore;
    private final LanternKeyStoreManager keyStoreManager;
    private volatile SSLContext serverContext;

    @Inject
    public CertTrackingSslEngineSource(
            final LanternTrustStore trustStore,
            final LanternKeyStoreManager keyStoreManager) {
        this.trustStore = trustStore;
        this.keyStoreManager = keyStoreManager;
    }

    @Override
    public SSLEngine newSslEngine() {
        if (LanternUtils.isFallbackProxy()) {
            return fallbackProxySslEngine();
        } else {
            return standardSslEngine(new CertTrackingTrustManager());
        }
    }

    private SSLEngine fallbackProxySslEngine() {
        LOG.debug("Using fallback proxy context");
        if (this.serverContext == null) {
            this.serverContext = buildFallbackServerContext();
        }
        try {
            final SSLEngine engine = this.serverContext.createSSLEngine();
            engine.setUseClientMode(false);
            configureCipherSuites(engine);
            return engine;
        } catch (final Exception e) {
            throw new Error(
                    "Failed to initialize the server-side SSLContext", e);
        }
    }

    private SSLContext buildFallbackServerContext() {
        final String PASS = "Be Your Own Lantern";
        InputStream is = null;
        try {
            final KeyStore ks = KeyStore.getInstance("JKS");

            final File keystore = new File(LanternUtils.getKeystorePath());
            is = new FileInputStream(keystore);
            ks.load(is, PASS.toCharArray());

            // Set up key manager factory to use our key store
            final KeyManagerFactory kmf =
                    KeyManagerFactory.getInstance("SunX509");
            kmf.init(ks, PASS.toCharArray());

            // Initialize the SSLContext to work with our key managers.
            final SSLContext context = SSLContext.getInstance("TLS");

            // NO CLIENT AUTH!!
            context.init(kmf.getKeyManagers(), null, null);
            return context;
        } catch (final KeyStoreException e) {
            throw new Error("Could not load fallback ssl context", e);
        } catch (NoSuchAlgorithmException e) {
            throw new Error("Could not load fallback ssl context", e);
        } catch (CertificateException e) {
            throw new Error("Could not load fallback ssl context", e);
        } catch (IOException e) {
            throw new Error("Could not load fallback ssl context", e);
        } catch (UnrecoverableKeyException e) {
            throw new Error("Could not load fallback ssl context", e);
        } catch (KeyManagementException e) {
            throw new Error("Could not load fallback ssl context", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
    }

    private SSLEngine standardSslEngine(
            final CertTrackingTrustManager trustManager) {
        LOG.debug("Using standard SSL context");
        try {
            final SSLContext context = SSLContext.getInstance("TLS");
            context.init(this.keyStoreManager.getKeyManagerFactory()
                    .getKeyManagers(),
                    new TrustManager[] { trustManager }, null);
            final SSLEngine engine = context.createSSLEngine();
            engine.setUseClientMode(false);
            engine.setNeedClientAuth(true);
            configureCipherSuites(engine);
            return engine;
        } catch (final Exception e) {
            throw new Error(
                    "Failed to initialize the client-side SSLContext", e);
        }
    }

    private void configureCipherSuites(final SSLEngine engine) {
        final String[] suites = IceConfig.getCipherSuites();
        if (suites != null && suites.length > 0) {
            engine.setEnabledCipherSuites(suites);
        } else {
            // Can be null in tests.
            LOG.warn("No cipher suites?");
        }
    }

    private class CertTrackingTrustManager implements X509TrustManager {

        private final Logger log = LoggerFactory.getLogger(getClass());

        @Override
        public void checkClientTrusted(final X509Certificate[] chain,
                String arg1)
                throws CertificateException {
            log.debug("Checking client trusted... {}", chain);
            final X509Certificate cert = chain[0];
            if (!LanternUtils.isFallbackProxy() &&
                    !trustStore.containsCertificate(cert)) {
                log.warn("Certificate is not trusted!!");
                throw new CertificateException("not trusted");
            }

            log.debug("Certificate trusted");
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
