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
import java.util.concurrent.atomic.AtomicReference;

import javax.net.ssl.KeyManagerFactory;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.apache.commons.lang3.StringUtils;
import org.littleshoot.proxy.KeyStoreManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LanternKeyStoreManager implements KeyStoreManager, LanternService {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File CONFIG_DIR;
    
    public final File KEYSTORE_FILE;
    
    private final File CERT_FILE;

    private static final String PASS;

    static {
        //initialize PASS to a value with 128 bits of entropy
        byte[] bytes = new byte[16];
        new SecureRandom().nextBytes(bytes);
        PASS = Base64.encodeBase64URLSafeString(bytes);
    }

    private static final String KEYSIZE = "2048";
    
    private static final String ALG = "RSA";

    private String localCert;

    private final AtomicReference<KeyManagerFactory> keyManagerFactoryRef = 
            new AtomicReference<KeyManagerFactory>();
    

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
        Runtime.getRuntime().addShutdownHook(new Thread (new Runnable() {
            @Override
            public void run() {
                log.debug("Deleting keystore file on shutdown");
                LanternUtils.fullDelete(KEYSTORE_FILE);
            }
        }, "Keystore-Delete-Thread"));
    }
    
    @Override
    public void start() {
        reset();
    }

    @Override
    public void stop() {}


    private void reset() {
        log.debug("RESETTING KEYSTORE AND TRUSTSTORE!!");
        LanternUtils.fullDelete(KEYSTORE_FILE);
        createKeyStore();
        LanternUtils.waitForFile(KEYSTORE_FILE);
    }

    private void createKeyStore() {
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

    @Override
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
            LanternUtils.waitForFile(KEYSTORE_FILE);
        }
    }

    @Override
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

    @Override
    public char[] getCertificatePassword() {
        return PASS.toCharArray();
    }

    @Override
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
