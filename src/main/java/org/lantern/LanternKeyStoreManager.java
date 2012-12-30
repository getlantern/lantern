package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.security.SecureRandom;
import java.util.Arrays;

import javax.net.ssl.TrustManager;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.apache.commons.lang3.StringUtils;
import org.lantern.state.Model;
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
    
    private final File TRUSTSTORE_FILE;
    
    private final File CERT_FILE;
    
    private static final String PASS = 
        String.valueOf(new SecureRandom().nextLong());
    
    private static final String KEYSIZE = "2048";
    
    private static final String ALG = "RSA";

    private String localCert;
    
    private final TrustManager[] trustManagers;

    private final LanternTrustManager lanternTrustManager;

    private final Model model;

    @Inject
    public LanternKeyStoreManager(final Model model, 
        final CertTracker certTracker) {
        this(null, model, certTracker);
    }
    
    public LanternKeyStoreManager(final File rootDir, final Model model, 
        final CertTracker certTracker) {
        this.model = model;
        CONFIG_DIR = rootDir != null ? rootDir : LanternConstants.CONFIG_DIR;
        KEYSTORE_FILE = 
            new File(CONFIG_DIR, "lantern_keystore.jks");
        TRUSTSTORE_FILE = 
            new File(CONFIG_DIR, "lantern_truststore.jks");
        CERT_FILE = 
            new File(CONFIG_DIR, "local_lantern_cert");
        
        fullDelete(KEYSTORE_FILE);
        fullDelete(TRUSTSTORE_FILE);

        if (!CONFIG_DIR.isDirectory()) {
            if (!CONFIG_DIR.mkdir()) {
                log.error("Could not create config dir!! "+CONFIG_DIR);
            }
        }
        reset();
        createTrustStore();
        
        this.lanternTrustManager = 
            new LanternTrustManager(this, TRUSTSTORE_FILE, PASS, certTracker);
        
        trustManagers = new TrustManager[] {
            lanternTrustManager
        };
        Runtime.getRuntime().addShutdownHook(new Thread (new Runnable() {
            @Override
            public void run() {
                fullDelete(KEYSTORE_FILE);
                fullDelete(TRUSTSTORE_FILE);
            }
        }, "Keystore-Delete-Thread"));
    }
    
    private void fullDelete(final File file) {
        file.deleteOnExit();
        if (file.isFile() && !file.delete()) {
            log.error("Could not delete file {}!!", file);
        }
    }

    private void createTrustStore() {
        if (TRUSTSTORE_FILE.isFile()) {
            log.info("Trust store already exists");
            return;
        }
        final String dummyCn = model.getNodeId();
        log.debug("Dummy CN is: {}", dummyCn);
        final String result = LanternUtils.runKeytool("-genkey", "-alias", 
            "foo", "-keysize", KEYSIZE, "-validity", "365", "-keyalg", ALG, 
            "-dname", "CN="+dummyCn, "-keystore", 
            TRUSTSTORE_FILE.getAbsolutePath(), "-keypass", PASS, 
            "-storepass", PASS);
        log.debug("Got result of creating trust store: {}", result);
    }

    private void reset() {
        log.debug("RESETTING KEYSTORE AND TRUSTSTORE!!");
        if (KEYSTORE_FILE.isFile()) {
            log.info("Deleting existing keystore file at: " +
                KEYSTORE_FILE.getAbsolutePath());
            KEYSTORE_FILE.delete();
        }
        
        if (TRUSTSTORE_FILE.isFile()) {
            log.info("Deleting existing truststore file at: " +
                TRUSTSTORE_FILE.getAbsolutePath());
            TRUSTSTORE_FILE.delete();
        }
        
        createKeyStore();

        waitForFile(KEYSTORE_FILE);
        /*
        log.info("Importing cert");
        nativeCall("keytool", "-import", "-noprompt", "-file", CERT_FILE.getName(), 
            "-alias", AL, "-keystore", TRUSTSTORE_FILE.getName(), "-storepass", 
            PASS);
            */

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
        /*
        final String result = LanternUtils.runKeytool("-genkey", 
            "-alias", dummyId, 
            "-keysize", KEYSIZE, 
            "-dname", "CN="+dummyId, // Required
            "-keypass", PASS, 
            "-storepass", PASS, 
            "-keystore", KEYSTORE_FILE.getAbsolutePath());
        */
        
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
        final String genKeyResult = getKey(normalizedAlias);
        
        log.info("Result of keytool -genkey call: {}", genKeyResult);
        
        waitForFile(KEYSTORE_FILE);
        
        // Now grab our newly-generated cert. All of our trusted peers will
        // use this to connect.
        final String exportCertResult = LanternUtils.runKeytool("-exportcert", "-alias", 
            normalizedAlias, "-keystore", KEYSTORE_FILE.getAbsolutePath(), 
            "-storepass", PASS, "-file", CERT_FILE.getAbsolutePath());
        log.info("Result of keytool -exportcert call: {}", exportCertResult);
        waitForFile(CERT_FILE);
        
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

    private String getKey(final String normalizedAlias) {
        return LanternUtils.runKeytool("-genkey", "-alias", 
            normalizedAlias, "-keysize", KEYSIZE, "-validity", "365", "-keyalg", ALG, 
            "-dname", "CN="+normalizedAlias, "-keypass", PASS, "-storepass", 
            PASS, "-keystore", KEYSTORE_FILE.getAbsolutePath());
    }

    /**
     * The completion of the native calls is dependent on OS process 
     * scheduling, so we need to wait until files actually exist.
     * 
     * @param file The file to wait for.
     */
    private void waitForFile(final File file) {
        int i = 0;
        while (!file.isFile() && i < 100) {
            try {
                Thread.sleep(80);
                i++;
            } catch (final InterruptedException e) {
                log.error("Interrupted?", e);
            }
        }
        if (!file.isFile()) {
            log.error("Still could not create file at: {}", file);
        } else {
            log.info("Successfully created file at: {}", file);
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
    public InputStream trustStoreAsInputStream() {
        try {
            return new FileInputStream(TRUSTSTORE_FILE);
        } catch (final FileNotFoundException e) {
            log.error("Trust store file not found", e);
            throw new Error("Could not find truststore file!!");
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
    
    @Override
    public void addBase64Cert(final String id, final String base64Cert) 
        throws IOException {
        this.lanternTrustManager.addBase64Cert(id, base64Cert);
    }

    @Override
    public TrustManager[] getTrustManagers() {
        return Arrays.copyOf(trustManagers, trustManagers.length);
    }

    public LanternTrustManager getTrustManager() {
        return this.lanternTrustManager;
    }
}
