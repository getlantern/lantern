package org.lantern;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.security.GeneralSecurityException;
import java.security.InvalidKeyException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.NoSuchProviderException;
import java.security.Principal;
import java.security.PublicKey;
import java.security.SignatureException;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

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
        addStaticCerts();
        
        // This has to go after the certs are added!!
        this.keyStore = getKs();
    }
    
    private void addStaticCerts() {
        addCert("google-equifax-root.crt", "equifax-google-root-cert");
        addCert("lantern_littleproxy_cert", "littleproxy");
    }

    private void addCert(final String fileName, final String alias) {
        final File cert = new File(fileName);
        if (!cert.isFile()) {
            log.error("No cert at "+cert);
            System.exit(1);
        }
        log.info("Importing cert");
        final String result = LanternUtils.runKeytool("-import", 
            "-noprompt", "-file", cert.getName(), 
            "-alias", alias, "-keystore", 
            trustStoreFile.getAbsolutePath(), "-storepass",  this.password);
        
        log.info("Result of running keytool: {}", result);
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
        
        
        // TODO: We should be able to just add it to the trust store here 
        // without saving
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

    @Override
    public X509Certificate[] getAcceptedIssuers() {
        return new X509Certificate[0];
    }

    @Override
    public void checkClientTrusted(final X509Certificate[] chain, 
        final String authType) throws CertificateException {
        log.info("CHECKING IF CLIENT IS TRUSTED");
        authenticate(chain, authType);
    }

    @Override
    public void checkServerTrusted(final X509Certificate[] chain, 
        final String authType) throws CertificateException {
        log.info("CHECKING IF SERVER IS TRUSTED");
        authenticate(chain, authType);
    }

    private void authenticate(final X509Certificate[] chain, 
        final String authType) throws CertificateException {
        if (chain == null || chain.length == 0) {
            log.warn("Null or empty chain");
            throw new IllegalArgumentException(
                "null or zero-length certificate chain");
        }
        if (authType == null || authType.length() == 0) {
            log.warn("Null or empty auth type");
            throw new IllegalArgumentException(
                "null or zero-length authentication type");
        }
        
        final Collection<String> peerIdentity = getPeerIdentity(chain[0]);
        
        final X509Certificate cert = chain[0];
        final String name = cert.getSubjectX500Principal().getName();
        if (StringUtils.isBlank(name)) {
            log.warn("No name in cert!!");
            throw new CertificateException("No name!!");
        }
        
        final int chainSize = chain.length;
        final String alias = StringUtils.substringAfterLast(name, "CN=");
        
        // Check for the hard-coded littleproxy cert as well as self-signed 
        // peer certs here. Self-signed certs are the only certs in the chain.
        if (alias.equals("littleproxy") || chainSize == 1) {
            log.info("CHECKING FOR CERTIFICATE UNDER: " + alias);
            try {
                final Certificate local = this.keyStore.getCertificate(alias);
                if (local == null) {
                    log.warn("No matching cert for: "+alias);
                    throw new CertificateException("No cert for "+ alias);
                }
                
                // Verifies that this certificate was signed using the private 
                // key that corresponds to the specified public key.
                // In this case the local cert was added through a TLS 
                // connection to Google Talk, and that connection *only* 
                // accepts certificates that are signed by Google's root signing
                // cert from equifax. Note this should of course verify because
                // it should be the exact same cert we learned about through 
                // the secure connection to Google Talk.
                local.verify(cert.getPublicKey());
                if (!local.equals(cert)) {
                    log.warn("Certs not equal:\n"+local+"\n and:\n"+cert);
                    throw new CertificateException("Did not recognize cert: "+cert);
                } else {
                    log.info("Verified cert!!");
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
        } else {
            // Otherwise check if we trust the signing cert.
            log.debug("Received signed cert...");
            try {
                final X509Certificate suppliedRootCert = chain[chainSize - 1];
                final String rootAlias = 
                    this.keyStore.getCertificateAlias(suppliedRootCert);
                final boolean trusted = rootAlias != null;
                if (!trusted) {
                    log.warn("No alias matching signing cert!");
                    throw new CertificateException("No alias matching signing cert");
                } else {
                    log.info("Root certs matched for {}", rootAlias);
                    Principal principalLast = null;
                    for (int i = chainSize - 1; i >= 0 ; i--) {
                        final X509Certificate x509 = chain[i];
                        final Principal principalIssuer = x509.getIssuerDN();
                        final Principal principalSubject = x509.getSubjectDN();
                        if (principalLast != null) {
                            if (principalIssuer.equals(principalLast)) {
                                try {
                                    final PublicKey publickey =
                                        chain[i + 1].getPublicKey();
                                    chain[i].verify(publickey);
                                    log.info("Verified signature...");
                                }
                                catch (final GeneralSecurityException gsa) {
                                    throw new CertificateException(
                                         "Signature verification failed for " + 
                                         peerIdentity, gsa);
                                }
                            }
                            else {
                                throw new CertificateException(
                                    "Subject/issuer verification failed for " + 
                                    peerIdentity);
                            }
                        }
                        principalLast = principalSubject;
                    }
                    log.info("Verified full chain of length: {}", chainSize);
                }
            }
            catch (final KeyStoreException e) {
                log.warn("Exception accessing keystore!", e);
                throw new CertificateException("No keystore!!");
            }
        }
    }
    

    private static Pattern cnPattern = Pattern.compile("(?i)(cn=)([^,]*)");
    
    /**
     * Returns the identity of the remote server as defined in the specified certificate. The
     * identity is defined in the subjectDN of the certificate and it can also be defined in
     * the subjectAltName extension of type "xmpp". When the extension is being used then the
     * identity defined in the extension in going to be returned. Otherwise, the value stored in
     * the subjectDN is returned.
     *
     * @param x509Certificate the certificate the holds the identity of the remote server.
     * @return the identity of the remote server as defined in the specified certificate.
     */
    private  Collection<String> getPeerIdentity(final X509Certificate x509Certificate) {
        String name = x509Certificate.getSubjectDN().getName();
        Matcher matcher = cnPattern.matcher(name);
        if (matcher.find()) {
            name = matcher.group(2);
        }
        // Create an array with the unique identity
        final Collection<String> names = new ArrayList<String>();
        names.add(name);
        return names;
    }

    public String getTruststorePath() {
        return trustStoreFile.getAbsolutePath();
    }

    public String getTruststorePassword() {
        return this.password;
    }

    public KeyStore getTruststore() {
        return this.keyStore;
    }
}
