package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.security.SecureRandom;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.apache.commons.lang3.StringUtils;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.util.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LanternKeyStoreManager implements KeyStoreManager {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File CONFIG_DIR;
    
    public final File KEYSTORE_FILE;
    
    
    private final File CERT_FILE;
    
    private static final String PASS = 
        String.valueOf(new SecureRandom().nextLong());
    
    private static final String KEYSIZE = "2048";
    
    private static final String ALG = "RSA";

    private String localCert;

    @Inject
    public LanternKeyStoreManager() {
        this(null);
    }
    
    public LanternKeyStoreManager(final File rootDir) {
        CONFIG_DIR = rootDir != null ? rootDir : LanternConstants.CONFIG_DIR;
        KEYSTORE_FILE = new File(CONFIG_DIR, "lantern_keystore.jks");
        CERT_FILE = new File(CONFIG_DIR, "local_lantern_cert");
        
        LanternUtils.fullDelete(KEYSTORE_FILE);

        if (!CONFIG_DIR.isDirectory()) {
            if (!CONFIG_DIR.mkdir()) {
                log.error("Could not create config dir!! "+CONFIG_DIR);
            }
        }
        reset();
        Runtime.getRuntime().addShutdownHook(new Thread (new Runnable() {
            @Override
            public void run() {
                LanternUtils.fullDelete(KEYSTORE_FILE);
            }
        }, "Keystore-Delete-Thread"));
    }

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
        final String normalizedAlias = 
                FileUtils.removeIllegalCharsFromFileName(jid);
        final String genKeyResult = 
            LanternUtils.runKeytool("-genkey", "-alias", 
                normalizedAlias, "-keysize", KEYSIZE, "-validity", "365", 
                "-keyalg", ALG, 
                "-dname", "CN="+normalizedAlias, "-keypass", PASS, "-storepass", 
                PASS, "-keystore", KEYSTORE_FILE.getAbsolutePath());
        
        log.info("Result of keytool -genkey call: {}", genKeyResult);
        
        // Now grab our newly-generated cert. All of our trusted peers will
        // use this to connect.
        // See: 
        // http://docs.oracle.com/javase/6/docs/technotes/tools/solaris/keytool.html
        // for a discussion of export versus exportcert (basically we use
        // export for backwards compatibility).
        final String exportCertResult = LanternUtils.runKeytool(
            "-export", 
            "-alias", normalizedAlias, 
            "-keystore", KEYSTORE_FILE.getAbsolutePath(), 
            "-storepass", PASS, 
            "-file", CERT_FILE.getAbsolutePath());
        
        log.info("Result of keytool -exportcert call: {}", exportCertResult);
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
        if (StringUtils.isBlank(localCert)) {
            generateLocalCert(id);
        }
        return localCert;
    }

    @Override
    public InputStream keyStoreAsInputStream() {
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
}
