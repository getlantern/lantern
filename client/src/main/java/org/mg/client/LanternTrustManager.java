package org.mg.client;

import java.io.IOException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;

import javax.net.ssl.X509TrustManager;

import org.apache.commons.lang.StringUtils;
import org.littleshoot.proxy.KeyStoreManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Trust manager for Lantern connections.
 */
public class LanternTrustManager implements X509TrustManager {


    private final Logger log = LoggerFactory.getLogger(getClass());
    private final KeyStoreManager ksm;
    
    public LanternTrustManager(final KeyStoreManager ksm) {
        this.ksm = ksm;
    }
    
    private KeyStore getKs() {
        try {
            final KeyStore ks = KeyStore.getInstance("JKS");
            ks.load(this.ksm.trustStoreAsInputStream(),
                    this.ksm.getKeyStorePassword());
            return ks;
        } catch (final KeyStoreException e) {
            log.error("Key store error?", e);
        } catch (final NoSuchAlgorithmException e) {
            log.error("Key store error?", e);
        } catch (final CertificateException e) {
            log.error("Key store error?", e);
        } catch (final IOException e) {
            log.error("Key store error?", e);
        }
        throw new Error("Could not create trust manager!");
    }

    public X509Certificate[] getAcceptedIssuers() {
        return new X509Certificate[0];
    }

    public void checkClientTrusted(final X509Certificate[] chain, 
        final String authType) throws CertificateException {
        System.err.println(
                "UNKNOWN CLIENT CERTIFICATE: " + chain[0].getSubjectDN());
    }

    public void checkServerTrusted(final X509Certificate[] chain, 
        final String authType) throws CertificateException {
        System.out.println("CHECKING IF SERVER IS TRUSTED");
        if (chain == null || chain.length == 0) {
            throw new IllegalArgumentException(
                "null or zero-length certificate chain");
        }
        if (authType == null || authType.length() == 0) {
            throw new IllegalArgumentException(
                "null or zero-length authentication type");
        }
        
        final X509Certificate cert = chain[0];
        final String name = cert.getSubjectX500Principal().getName();
        if (StringUtils.isBlank(name)) {
            throw new CertificateException("No name!!");
        }
        final String alias = StringUtils.substringAfterLast(name, "CN=");
        System.err.println(
                "CHECKING SERVER CERTIFICATE FOR: " + alias);
        
        System.err.println("VERIFYING CERT: "+cert);
        log.info("Checking certs");
        try {
            final Certificate local = getKs().getCertificate(alias);
            if (local == null || !local.equals(cert)) {
                log.info("Certs not equal:\n"+local+"\n and:\n"+cert);
                throw new CertificateException("Did not recognize cert: "+cert);
            }
        } catch (final KeyStoreException e) {
            throw new CertificateException("Did not recognize cert: "+cert, e);
        }
        log.info("Certificates matched!");
        
    }
}
