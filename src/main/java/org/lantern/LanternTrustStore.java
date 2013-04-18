package org.lantern;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.security.Security;
import java.security.UnrecoverableKeyException;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.Enumeration;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.jboss.netty.channel.ChannelPipeline;
import org.lantern.event.Events;
import org.lantern.event.PeerCertEvent;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.util.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LanternTrustStore {

    private final static Logger log = 
        LoggerFactory.getLogger(LanternTrustStore.class);

    private static final String KEYSIZE = "2048";

    public static final String PASS =
        String.valueOf(new SecureRandom().nextLong());

    private static final String ALG = "RSA";

    private SSLContext sslClientContext;
    private final KeyStoreManager ksm;

    private KeyManagerFactory keyManagerFactory;

    /**
     * We re-create a random trust store on each run. This requires that
     * we re-negotiate keys with peers on new connections, which will not
     * always be the case if the remote client is longer lived than we are
     * (i.e., the remote client thinks it has our key, but our key has changed).
     * 
     * Note this is not static so that tests don't conflict using the same
     * trust store.
     */
    public final File TRUSTSTORE_FILE =
        new File(LanternClientConstants.CONFIG_DIR,
            String.valueOf(new SecureRandom().nextLong()));

    @Inject
    public LanternTrustStore(final KeyStoreManager ksm) {
        this.ksm = ksm;
        configureTrustStore();
        System.setProperty("javax.net.ssl.trustStore",
            TRUSTSTORE_FILE.getAbsolutePath());
        onTrustStoreChanged();
        Runtime.getRuntime().addShutdownHook(new Thread (new Runnable() {
            @Override
            public void run() {
                LanternUtils.fullDelete(TRUSTSTORE_FILE);
            }
        }, "Keystore-Delete-Thread"));
    }

    private void onTrustStoreChanged() {
        this.keyManagerFactory = loadKeyManagerFactory();
        sslClientContext = provideClientSslContext();
    }

    private void configureTrustStore() {
        LanternUtils.fullDelete(TRUSTSTORE_FILE);
        createTrustStore();
        addStaticCerts();
        log.debug("Created trust store!!");
    }

    private void createTrustStore() {
        if (TRUSTSTORE_FILE.isFile()) {
            log.error("Trust store already exists at "+TRUSTSTORE_FILE);
            return;
        }
        final String dummyCn = String.valueOf(new SecureRandom().nextLong());
        //final String dummyCn = model.getNodeId();
        log.debug("Dummy CN is: {}", dummyCn);
        final String result = LanternUtils.runKeytool("-genkey", "-alias",
            "foo", "-keysize", KEYSIZE, "-validity", "365", "-keyalg", ALG,
            "-dname", "CN="+dummyCn, "-keystore",
            TRUSTSTORE_FILE.getAbsolutePath(), "-keypass", PASS,
            "-storepass", PASS);
        log.debug("Got result of creating trust store: {}", result);
        LanternUtils.waitForFile(TRUSTSTORE_FILE);
    }

    private void addStaticCerts() {
        addCert("digicerthighassurancerootca", "certs/DigiCertHighAssuranceCA-3.cer");
        addCert("littleproxy", "certs/littleproxy.cer");
        addCert("equifaxsecureca", "certs/equifaxsecureca.cer");
    }

    private void addCert(final String alias, final String fileName) {
        final File cert = new File(fileName);
        addCert(alias, cert);
    }

    public void addCert(final String alias, final File cert) {
        LanternUtils.addCert(alias, cert, TRUSTSTORE_FILE, PASS);
        onTrustStoreChanged();
    }

    public void addBase64Cert(final URI jid, final String base64Cert)
        throws IOException {
        log.debug("Adding base 64 cert for {} to store: {}", jid, TRUSTSTORE_FILE);
        Events.asyncEventBus().post(new PeerCertEvent(jid, base64Cert));
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
        final String normalizedAlias =
            FileUtils.removeIllegalCharsFromFileName(jid.toASCIIString());
        final File certFile = new File(normalizedAlias);
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

        log.debug("Using normalized alias {}", normalizedAlias);
        // Make sure we delete the old one (will fail when it doesn't exist -
        // this is expected).
        deleteCert(normalizedAlias);
        addCert(normalizedAlias, certFile);

        // get rid of our imported file
        certFile.delete();
        certFile.deleteOnExit();
    }

    private String getTrustStorePath() {
        return TRUSTSTORE_FILE.getAbsolutePath();
    }

    /**
     * Accessor for the client SSL context. This is regenerated whenever
     * we receive new certificates. This also differs from the server SSL
     * context in that it is initialized with null array of trust managers,
     * which signals the use of the default trust managers specified in
     * the javax.net.ssl.trustStore property. That overrides java's default
     * trusted certificates. The same strategy can't be used on the server
     * side, however, because java explicitly requires a TrustManager for 
     * verifying trusted *clients* with mutual authentication turned on --
     * passing null trust managers doesn't trigger the use of the default
     * trust store for client authentication like it does for server 
     * authentication.
     * 
     * @return The client SSL context.
     */
    public SSLContext getClientContext() {
        return sslClientContext;
    }

    private SSLContext provideClientSslContext() {
        try {
            final SSLContext context = SSLContext.getInstance("TLS");

            // Note that specifying null for the trust managers here simply
            // tells the JVM to load them from our trusted certs keystore.
            // We set that specially with our call to:
            //
            // System.setProperty("javax.net.ssl.trustStore",
            //     TRUSTSTORE_FILE.getAbsolutePath());
            //
            // This is the "safe" way to do it because we completely override
            // all the JVM's default trusted certs and only trust the few
            // certs we specify, and that file is generated on the fly
            // on each run, added to dynamically, and reloaded here.
            context.init(this.keyManagerFactory.getKeyManagers(), null, null);
            return context;
        } catch (final Exception e) {
            throw new Error(
                    "Failed to initialize the client-side SSLContext", e);
        }
    }
    

    private KeyManagerFactory loadKeyManagerFactory() {
        String algorithm =
            Security.getProperty("ssl.KeyManagerFactory.algorithm");
        if (algorithm == null) {
            algorithm = "SunX509";
        }
        try {
            final KeyStore ks = KeyStore.getInstance("JKS");
            ks.load(ksm.keyStoreAsInputStream(), ksm.getKeyStorePassword());

            // Set up key manager factory to use our key store
            final KeyManagerFactory kmf = KeyManagerFactory.getInstance(algorithm);
            kmf.init(ks, ksm.getCertificatePassword());

            return kmf;
        } catch (final KeyStoreException e) {
            throw new Error("Key manager issue", e);
        } catch (final UnrecoverableKeyException e) {
            throw new Error("Key manager issue", e);
        } catch (final NoSuchAlgorithmException e) {
            throw new Error("Key manager issue", e);
        } catch (final CertificateException e) {
            throw new Error("Key manager issue", e);
        } catch (final IOException e) {
            throw new Error("Key manager issue", e);
        }
    }

    public void deleteCert(final String alias) {
        final String deleteResult = LanternUtils.runKeytool("-delete",
            "-alias", alias,
            "-keystore", getTrustStorePath(),
            "-storepass", PASS);

        log.debug("Result of deleting old cert: {}", deleteResult);
        onTrustStoreChanged();
    }


    private static void listEntries(final KeyStore ks) {
        try {
            final Enumeration<String> aliases = ks.aliases();
            while (aliases.hasMoreElements()) {
                final String alias = aliases.nextElement();
                //System.err.println(alias+": "+ks.getCertificate(alias));
                System.err.println(alias);
            }
        } catch (final KeyStoreException e) {
            log.warn("KeyStore error", e);
        }
    }
    
    public static void listEntries(final File keyStore, final String pass) {
        final KeyStore ks = loadKeyStore(keyStore, pass);
        listEntries(ks);
    }
    
    public static KeyStore loadKeyStore(final File keyStore, final String pass) {
        InputStream is = null;
        try {
            is = new FileInputStream(keyStore);
            final KeyStore ks = KeyStore.getInstance(KeyStore.getDefaultType());
            ks.load(is, pass.toCharArray());
            return ks;
        } catch (final KeyStoreException e) {
            log.warn("Could not load keystore?", e);
            throw new RuntimeException("Could not load keystore", e);
        } catch (final NoSuchAlgorithmException e) {
            log.warn("Could not load keystore?", e);
            throw new RuntimeException("Could not load keystore", e);
        } catch (final CertificateException e) {
            log.warn("Could not load keystore?", e);
            throw new RuntimeException("Could not load keystore", e);
        } catch (final FileNotFoundException e) {
            log.warn("Could not load keystore?", e);
            throw new RuntimeException("Could not load keystore", e);
        } catch (final IOException e) {
            log.warn("Could not load keystore?", e);
            throw new RuntimeException("Could not load keystore", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
    }

    public void listEntries() {
        listEntries(TRUSTSTORE_FILE, PASS);
    }
    
    public KeyStore loadKeyStore() {
        return loadKeyStore(TRUSTSTORE_FILE, PASS);
    }

    /**
     * Checks if the trust store contains exactly this certificate. This 
     * doesn't worry about certificate chaining or anything like that -- 
     * this trust store must instead contain the actual certificate.
     * 
     * @param cert The certificate to check.
     * @return <code>true</code> if the trust store contains the certificate,
     * otherwise <code>false</code>.
     */
    public boolean containsCertificate(final X509Certificate cert) {
        log.debug("Loading trust store: {}", TRUSTSTORE_FILE);
        final KeyStore ks = loadKeyStore();
        
        // We could use getCertificateAlias here, but that will iterate through
        // everything, potentially causing issues when there are a lot of certs.
        final String alias = 
            cert.getIssuerDN().getName().substring(3).toLowerCase();
        try {
            final Certificate existingCert = ks.getCertificate(alias);
            return existingCert.equals(cert);
        } catch (final KeyStoreException e) {
            log.warn("Exception accessing keystore", e);
            return false;
        }
    }

    public KeyManagerFactory getKeyManagerFactory() {
        return keyManagerFactory;
    }
}
