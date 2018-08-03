package org.lantern.simple;

import java.io.File;
import java.io.FileInputStream;
import java.security.KeyStore;
import java.security.Security;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;

import javax.net.ssl.KeyManager;
import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLEngine;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

import org.littleshoot.proxy.SslEngineSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class SimpleSslEngineSource implements SslEngineSource {
    private static final Logger LOG = LoggerFactory
            .getLogger(SimpleSslEngineSource.class);
    private static final String PASSWORD = "Be Your Own Lantern";
    private static final String PROTOCOL = "TLS";

    private final File keyStoreFile;
    private SSLContext sslContext;

    public SimpleSslEngineSource(String keyStorePath) {
        if (keyStorePath != null) {
            this.keyStoreFile = new File(keyStorePath);
        } else {
            this.keyStoreFile = null;
        }
        initializeSSLContext();
    }

    public SimpleSslEngineSource() {
        this(null);
    }

    @Override
    public SSLEngine newSslEngine() {
        return sslContext.createSSLEngine();
    }

    public SSLContext getSslContext() {
        return sslContext;
    }

    private void initializeSSLContext() {
        String algorithm = Security
                .getProperty("ssl.KeyManagerFactory.algorithm");
        if (algorithm == null) {
            algorithm = "SunX509";
        }

        try {
            final KeyStore ks = KeyStore.getInstance("JKS");
            KeyManager[] keyManagers = new KeyManager[0];

            if (keyStoreFile != null) {
                LOG.info("Initializing keystore from file: {}", keyStoreFile);
                // ks.load(new FileInputStream("keystore.jks"),
                // "changeit".toCharArray());
                ks.load(new FileInputStream(keyStoreFile),
                        PASSWORD.toCharArray());

                // Set up key manager factory to use our key store
                final KeyManagerFactory kmf =
                        KeyManagerFactory.getInstance(algorithm);
                kmf.init(ks, PASSWORD.toCharArray());

                keyManagers = kmf.getKeyManagers();
            }

            TrustManager[] trustManagers = new TrustManager[] { new X509TrustManager() {
                // TrustManager that trusts all servers
                @Override
                public void checkClientTrusted(X509Certificate[] arg0,
                        String arg1)
                        throws CertificateException {
                }

                @Override
                public void checkServerTrusted(X509Certificate[] arg0,
                        String arg1)
                        throws CertificateException {
                }

                @Override
                public X509Certificate[] getAcceptedIssuers() {
                    return null;
                }
            } };

            // Initialize the SSLContext to work with our key managers.
            sslContext = SSLContext.getInstance(PROTOCOL);
            sslContext.init(keyManagers, trustManagers, null);
        } catch (final Exception e) {
            throw new Error(
                    "Failed to initialize the server-side SSLContext", e);
        }
    }

}
