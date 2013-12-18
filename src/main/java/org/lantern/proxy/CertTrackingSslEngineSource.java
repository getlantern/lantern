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
import java.util.Arrays;

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
            return fallbackSslEngine(new CertTrackingTrustManager());
        } else {
            return standardSslEngine(new CertTrackingTrustManager());
        }
    }
    

    private SSLEngine fallbackSslEngine(
            final CertTrackingTrustManager certTrackingTrustManager) {
        LOG.debug("Using fallback proxy context");
        if (this.serverContext == null) {
            this.serverContext = buildFallbackServerContext(certTrackingTrustManager);
        }
        try {
            final SSLEngine engine = this.serverContext.createSSLEngine();
            engine.setUseClientMode(false);
            // To reduce fingerprintability of fallbacks, we use the default cipher suites
            //configureCipherSuites(engine);
            return engine;
        } catch (final Exception e) {
            throw new Error(
                    "Failed to initialize the server-side SSLContext", e);
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
            LOG.debug("Setting cipher suites to: {}", Arrays.asList(suites));
            engine.setEnabledCipherSuites(suites);
        } else {
            // Can be null in tests.
            LOG.warn("No cipher suites?");
        }
    }

    private SSLContext buildFallbackServerContext(
            final CertTrackingTrustManager trustManager) {
        LOG.debug("Building fallback server context...");
        final String PASS = "Be Your Own Lantern";
        InputStream is = null;
        try {
            final KeyStore ks = KeyStore.getInstance("JKS");

            final String path = LanternUtils.getFallbackKeystorePath();
            final File keystore = new File(path);
            if (!keystore.isFile()) {
                LOG.error("No keystore file found at: "+keystore);
                throw new Error("No keystore file found at: "+keystore);
            }
            is = new FileInputStream(keystore);
            ks.load(is, PASS.toCharArray());

            // Set up key manager factory to use our key store
            final KeyManagerFactory kmf =
                    KeyManagerFactory.getInstance("SunX509");
            kmf.init(ks, PASS.toCharArray());

            // Initialize the SSLContext to work with our key managers.
            final SSLContext context = SSLContext.getInstance("TLS");

            // It's not clear why, but if we don't pass the TrustManager array
            // here, we get null cert chain errors on the server. This 
            // shouldn't happen because the trust managers should only matter
            // in the case of client authentication, but for some reason it
            // does. See FallbackProxyTest.
            context.init(kmf.getKeyManagers(), 
                new TrustManager[] { trustManager }, null);
            return context;
        } catch (final KeyStoreException e) {
            LOG.error("Could not load fallback ssl context", e);
            throw new Error("Could not load fallback ssl context", e);
        } catch (NoSuchAlgorithmException e) {
            LOG.error("Could not load fallback ssl context", e);
            throw new Error("Could not load fallback ssl context", e);
        } catch (CertificateException e) {
            LOG.error("Could not load fallback ssl context", e);
            throw new Error("Could not load fallback ssl context", e);
        } catch (IOException e) {
            LOG.error("Could not load fallback ssl context", e);
            throw new Error("Could not load fallback ssl context", e);
        } catch (UnrecoverableKeyException e) {
            LOG.error("Could not load fallback ssl context", e);
            throw new Error("Could not load fallback ssl context", e);
        } catch (KeyManagementException e) {
            LOG.error("Could not load fallback ssl context", e);
            throw new Error("Could not load fallback ssl context", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
    }

    private class CertTrackingTrustManager implements X509TrustManager {

        private final Logger log = LoggerFactory.getLogger(getClass());

        @Override
        public void checkClientTrusted(final X509Certificate[] chain,
                String arg1)
                throws CertificateException {
            log.debug("Checking client trusted... {}", Arrays.asList(chain));
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
