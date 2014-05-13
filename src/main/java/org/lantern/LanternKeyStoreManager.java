package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.security.Security;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateException;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

import javax.net.ssl.KeyManagerFactory;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LanternKeyStoreManager implements LanternService {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File CONFIG_DIR;
    
    public final File KEYSTORE_FILE;
    
    private final File CERT_FILE;

    private static final String PASS = 
            String.valueOf(new SecureRandom().nextLong());

    private static final String KEYSIZE = "2048";
    
    private static final String ALG = "RSA";

    private String localCert;

    private final AtomicReference<KeyManagerFactory> keyManagerFactoryRef = 
            new AtomicReference<KeyManagerFactory>();
    
    private final AtomicBoolean started = new AtomicBoolean(false);

    @Inject
    public LanternKeyStoreManager() {
        this(null);
    }
    
    public LanternKeyStoreManager(final File rootDir) {
        CONFIG_DIR = rootDir != null ? rootDir : LanternClientConstants.CONFIG_DIR;
        KEYSTORE_FILE = new File(CONFIG_DIR, "lantern_keystore.jks");
        CERT_FILE = new File(CONFIG_DIR, "local_lantern_cert");
        
        LanternUtils.fullDelete(KEYSTORE_FILE);

        if (!CONFIG_DIR.isDirectory()) {
            if (!CONFIG_DIR.mkdir()) {
                log.error("Could not create config dir!! "+CONFIG_DIR);
            }
        }
    }
    
    @Override
    public void start() {
        if (started.getAndSet(true)) {
            return;
        }
        reset();
    }

    @Override
    public void stop() {
        log.debug("Deleting keystore file on shutdown");
        LanternUtils.fullDelete(KEYSTORE_FILE);
    }


    private void reset() {
        log.debug("RESETTING KEYSTORE AND TRUSTSTORE!!");
        LanternUtils.fullDelete(KEYSTORE_FILE);
        createKeyStore();
        LanternUtils.waitForFile(KEYSTORE_FILE);
    }

    private void createKeyStore() {
        // Whenever the key store changes, we need to set the ref to null
        // so we don't pass stale versions of the key manager factory 
        // to callers.
        
        this.keyManagerFactoryRef.set(null);
        final String dummyId = String.valueOf(RandomUtils.nextInt());
        // Generate the keystore using a dummy ID.
        log.debug("Dummy ID is: {}", dummyId);
        log.debug("Creating keystore...");
        
        String result = LanternUtils.runKeytool("-genkey", 
            "-alias", dummyId, 
            "-keysize", KEYSIZE, 
            "-validity", "365", 
            "-keyalg", ALG, 
            "-dname", "CN="+dummyId, 
            "-keypass", PASS, 
            "-storepass", PASS, 
            "-keystore", KEYSTORE_FILE.getAbsolutePath());
        log.debug("Got response: {}", result);
        
        log.debug("Deleting dummy alias...");
        result = LanternUtils.runKeytool("-delete", "-alias", dummyId,
            "-keypass", PASS, "-storepass", PASS,
            "-keystore", KEYSTORE_FILE.getAbsolutePath());
        log.debug("Got response: {}", result);
        
        log.debug("Done creating keystore...");
    }

    private void generateLocalCert(final String jid) {
        // Whenever the key store changes, we need to set the ref to null
        // so we don't pass stale versions of the key manager factory 
        // to callers.
        this.keyManagerFactoryRef.set(null);
        final String genKeyResult = LanternUtils.runKeytool("-genkey", 
            "-alias", jid, 
            "-keysize", KEYSIZE, 
            "-validity", "365", 
            "-keyalg", ALG, 
            "-dname", "CN="+jid,
            "-keypass", PASS,
            "-storepass", PASS,
            "-keystore", KEYSTORE_FILE.getAbsolutePath());
        
        log.debug("Result of keytool -genkey call: {}", genKeyResult);
        
        // Now grab our newly-generated cert. All of our trusted peers will
        // use this to connect.
        // See: 
        // http://docs.oracle.com/javase/6/docs/technotes/tools/solaris/keytool.html
        // for a discussion of export versus exportcert (basically we use
        // export for backwards compatibility).
        final String exportCertResult = LanternUtils.runKeytool(
            "-export", 
            "-alias", jid, 
            "-keystore", KEYSTORE_FILE.getAbsolutePath(), 
            "-storepass", PASS, 
            "-file", CERT_FILE.getAbsolutePath());
        
        log.debug("Result of keytool -exportcert call: {}", exportCertResult);
        LanternUtils.waitForFile(CERT_FILE);
        
        try {
            final InputStream is = new FileInputStream(CERT_FILE);
            localCert = Base64.encodeBase64String(IOUtils.toByteArray(is));
        } catch (final FileNotFoundException e) {
            log.error("Cert file not found at "+CERT_FILE, e);
            throw new Error("Cert file not found", e);
        } catch (final IOException e) {
            log.error("Could not base 64 encode cert?", e);
            throw new Error("Could not base 64 encode cert?", e);
        }
    }

    public String getBase64Cert(final String id) {
        // The keystore file itself is created lazily, so make sure we have it
        // before proceeding here.
        waitForKeystore();
        if (StringUtils.isBlank(localCert)) {
            generateLocalCert(id);
        }
        return localCert;
    }

    private void waitForKeystore() {
        if (!KEYSTORE_FILE.isFile()) {
            start();
            LanternUtils.waitForFile(KEYSTORE_FILE);
        }
    }

    public InputStream keyStoreAsInputStream() {
        // The keystore file itself is created lazily, so make sure we have it
        // before proceeding here.
        waitForKeystore();
        try {
            return new FileInputStream(KEYSTORE_FILE);
        } catch (final FileNotFoundException e) {
            log.error("Key store file not found", e);
            throw new Error("Could not find keystore file!!");
        }
    }

    public char[] getCertificatePassword() {
        return PASS.toCharArray();
    }

    public char[] getKeyStorePassword() {
        return PASS.toCharArray();
    }
    

    public KeyManagerFactory getKeyManagerFactory() {
        if (this.keyManagerFactoryRef.get() != null) {
            return this.keyManagerFactoryRef.get();
        }
        String algorithm =
            Security.getProperty("ssl.KeyManagerFactory.algorithm");
        if (algorithm == null) {
            algorithm = "SunX509";
        }
        try {
            final KeyStore ks = KeyStore.getInstance("JKS");
            ks.load(keyStoreAsInputStream(), getKeyStorePassword());

            // Set up key manager factory to use our key store
            final KeyManagerFactory kmf = KeyManagerFactory.getInstance(algorithm);
            kmf.init(ks, getKeyStorePassword());

            this.keyManagerFactoryRef.set(kmf);
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
}
