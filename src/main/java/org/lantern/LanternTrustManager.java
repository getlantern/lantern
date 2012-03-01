package org.lantern;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.security.InvalidKeyException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.NoSuchProviderException;
import java.security.SignatureException;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;

import javax.net.ssl.X509TrustManager;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.util.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Trust manager for Lantern connections.
 */
public class LanternTrustManager implements X509TrustManager {


    private final Logger log = LoggerFactory.getLogger(getClass());
    private final KeyStoreManager ksm;
    private KeyStore keyStore;
    private final File trustStoreFile;
    private final String password;
    
    public LanternTrustManager(final KeyStoreManager ksm, 
        final File trustStoreFile, final String password) {
        this.ksm = ksm;
        this.trustStoreFile = trustStoreFile;
        this.password = password;
        this.keyStore = getKs();
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
    
    public void addBase64Cert(final String macAddress, final String base64Cert) 
        throws IOException {
        // Alright, we need to decode the certificate from base 64, write it
        // to a file, and then use keytool to import it.
        
        // Here's the keytool doc:
        /*
         * -importcert  [-v] [-noprompt] [-trustcacerts] [-protected]
         [-alias <alias>]
         [-file <cert_file>] [-keypass <keypass>]
         [-keystore <keystore>] [-storepass <storepass>]
         [-storetype <storetype>] [-providername <name>]
         [-providerclass <provider_class_name> [-providerarg <arg>]] ...
         [-providerpath <pathlist>]
         */
        final byte[] decoded = Base64.decodeBase64(base64Cert);
        final String fileName = 
            FileUtils.removeIllegalCharsFromFileName(macAddress);
        final File certFile = new File(fileName);
        OutputStream os = null;
        try {
            os = new FileOutputStream(certFile);
            IOUtils.copy(new ByteArrayInputStream(decoded), os);
        } catch (final IOException e) {
            log.error("Could not write to file: " + certFile, e);
            throw e;
        } finally {
            IOUtils.closeQuietly(os);
        }
        /*
         * -delete      [-v] [-protected] -alias <alias>
         [-keystore <keystore>] [-storepass <storepass>]
         [-storetype <storetype>] [-providername <name>]
         [-providerclass <provider_class_name> [-providerarg <arg>]] ...
         [-providerpath <pathlist>]
    
         */
        // Make sure we delete the old one.
        final String deleteResult = LanternUtils.runKeytool("-delete", 
            "-alias", fileName, "-keystore", trustStoreFile.getAbsolutePath(), 
            "-storepass", this.password);
        log.info("Result of deleting old cert: {}", deleteResult);
        
        final String importResult = LanternUtils.runKeytool("-importcert", 
            "-noprompt", "-alias", fileName, "-keystore", 
            trustStoreFile.getAbsolutePath(), 
            "-file", certFile.getAbsolutePath(), 
            "-keypass", this.password, "-storepass", this.password);
        log.info("Result of importing new cert: {}", importResult);
        
        // We need to reload the keystore with the latest data.
        this.keyStore = getKs();
        
        // get rid of our imported file
        certFile.delete();
    }

    public X509Certificate[] getAcceptedIssuers() {
        return new X509Certificate[0];
    }

    public void checkClientTrusted(final X509Certificate[] chain, 
        final String authType) throws CertificateException {
        log.info("UNKNOWN CLIENT CERTIFICATE: " + chain[0].getSubjectDN());
    }

    @Override
    public void checkServerTrusted(final X509Certificate[] chain, 
        final String authType) throws CertificateException {
        log.info("CHECKING IF SERVER IS TRUSTED");
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
        log.info("CHECKING SERVER CERTIFICATE FOR: " + alias);
        try {
            final Certificate local = this.keyStore.getCertificate(alias);
            if (local == null) {
                log.warn("No matching cert for: "+alias);
                throw new CertificateException("No cert for "+ alias);
            }
            local.verify(cert.getPublicKey());
            if (!local.equals(cert)) {
                log.info("Certs not equal:\n"+local+"\n and:\n"+cert);
                throw new CertificateException("Did not recognize cert: "+cert);
            }
        } catch (final KeyStoreException e) {
            throw new CertificateException("Did not recognize cert: "+cert, e);
        } catch (final InvalidKeyException e) {
            throw new CertificateException("Key: "+cert, e);
        } catch (final NoSuchAlgorithmException e) {
            throw new CertificateException("Algorithm: "+cert, e);
        } catch (final NoSuchProviderException e) {
            throw new CertificateException("Providert: "+cert, e);
        } catch (final SignatureException e) {
            throw new CertificateException("Sig: "+cert, e);
        }
        log.info("Certificates matched!");
        
    }
}
