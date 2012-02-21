package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;

import javax.net.ssl.TrustManager;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.littleshoot.proxy.KeyStoreManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


public class LanternKeyStoreManager implements KeyStoreManager {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File CONFIG_DIR;
    
    public final File KEYSTORE_FILE;
    
    private final File TRUSTSTORE_FILE;
    
    private final File CERT_FILE;
    
    private static final String PASS = 
        String.valueOf(LanternHub.secureRandom().nextLong());

    private String localCert;
    
    private final TrustManager[] trustManagers;

    private final LanternTrustManager lanternTrustManager;

    public LanternKeyStoreManager() {
        this(null);
    }
    
    public LanternKeyStoreManager(final File rootDir) {
        CONFIG_DIR = rootDir != null ? rootDir : LanternUtils.configDir();
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
        reset(LanternUtils.getMacAddress());
        createTrustStore();
        final File littleProxyCert = new File("lantern_littleproxy_cert");
        if (littleProxyCert.isFile()) {
            log.info("Importing cert");
            final String result = LanternUtils.runKeytool("-import", 
                "-noprompt", "-file", littleProxyCert.getName(), 
                "-alias", "littleproxy", "-keystore", 
                TRUSTSTORE_FILE.getAbsolutePath(), "-storepass",  PASS);
            
            log.info("Result of running keytool: {}", result);
        } else {
            log.warn("NO LITTLEPROXY CERT FILE TO IMPORT!!");
        }
        
        this.lanternTrustManager = 
            new LanternTrustManager(this, TRUSTSTORE_FILE, PASS);
        
        trustManagers = new TrustManager[] {
            lanternTrustManager
        };
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
        final String result = LanternUtils.runKeytool("-genkey", "-alias", 
            "foo", "-keysize", "1024", "-validity", "365", "-keyalg", "DSA", 
            "-dname", "CN="+LanternUtils.getMacAddress(), "-keystore", 
            TRUSTSTORE_FILE.getAbsolutePath(), "-keypass", PASS, 
            "-storepass", PASS);
        log.info("Got result of creating trust store: {}", result);
    }

    private void reset(final String macAddress) {
        log.info("RESETTING KEYSTORE AND TRUSTSTORE!!");
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
    
        // Note we use DSA instead of RSA because apparently only the JDK 
        // has RSA available.
        final String genKeyResult = LanternUtils.runKeytool("-genkey", "-alias", 
            macAddress, "-keysize", "1024", "-validity", "365", "-keyalg", "DSA", 
            "-dname", "CN="+macAddress, "-keypass", PASS, "-storepass", 
            PASS, "-keystore", KEYSTORE_FILE.getAbsolutePath());
        
        log.info("Result of keytool -genkey call: {}", genKeyResult);
        
        waitForFile(KEYSTORE_FILE);
        
        // Now grab our newly-generated cert. All of our trusted peers will
        // use this to connect.
        final String exportCertResult = LanternUtils.runKeytool("-exportcert", "-alias", 
            macAddress, "-keystore", KEYSTORE_FILE.getAbsolutePath(), 
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


        /*
        log.info("Importing cert");
        nativeCall("keytool", "-import", "-noprompt", "-file", CERT_FILE.getName(), 
            "-alias", AL, "-keystore", TRUSTSTORE_FILE.getName(), "-storepass", 
            PASS);
            */

    }

    /**
     * The completion of the native calls is dependent on OS process 
     * scheduling, so we need to wait until files actually exist.
     * 
     * @param file The file to wait for.
     */
    private void waitForFile(final File file) {
        int i = 0;
        while (!file.isFile() && i < 20) {
            try {
                Thread.sleep(200);
                i++;
            } catch (final InterruptedException e) {
                log.error("Interrupted?", e);
            }
        }
    }

    public String getBase64Cert() {
        return localCert;
    }

    public InputStream keyStoreAsInputStream() {
        try {
            return new FileInputStream(KEYSTORE_FILE);
        } catch (final FileNotFoundException e) {
            log.error("Key store file not found", e);
            throw new Error("Could not find keystore file!!");
        }
    }
    
    public InputStream trustStoreAsInputStream() {
        try {
            return new FileInputStream(TRUSTSTORE_FILE);
        } catch (final FileNotFoundException e) {
            log.error("Trust store file not found", e);
            throw new Error("Could not find truststore file!!");
        }
    }

    public char[] getCertificatePassword() {
        return PASS.toCharArray();
    }

    public char[] getKeyStorePassword() {
        return PASS.toCharArray();
    }
    
    public void addBase64Cert(final String macAddress, final String base64Cert) 
        throws IOException {
        this.lanternTrustManager.addBase64Cert(macAddress, base64Cert);
    }

    public TrustManager[] getTrustManagers() {
        return Arrays.copyOf(trustManagers, trustManagers.length);
    }
}
