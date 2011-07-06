package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;

import javax.net.ssl.TrustManager;

import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.util.CommonUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


public class LanternKeyStoreManager implements KeyStoreManager {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File CONFIG_DIR = LanternUtils.configDir();
    
    private final File KEYSTORE_FILE = 
        new File(CONFIG_DIR, "lantern_keystore.jks");
    
    private final File TRUSTSTORE_FILE = 
        new File(CONFIG_DIR, "lantern_truststore.jks");
    
    //private final File CERT_FILE = 
    //    new File(CONFIG_DIR, "local_lantern_cert");
    
    private static final String PASS = "Be Your Own Lantern";

    //private String localCert;
    
    private final TrustManager[] trustManagers;

    private final LanternTrustManager lanternTrustManager;

    public LanternKeyStoreManager() {
        this(true);
    }
    
    public LanternKeyStoreManager(final boolean regenerate) {
        if (!CONFIG_DIR.isDirectory()) {
            if (!CONFIG_DIR.mkdir()) {
                log.error("Could not create config dir!! "+CONFIG_DIR);
            }
        }
        if(regenerate) {
            reset(LanternUtils.getMacAddress());
        }
        createTrustStore();
        final File littleProxyCert = new File("lantern_littleproxy_cert");
        if (littleProxyCert.isFile()) {
            log.info("Importing cert");
            CommonUtils.nativeCall("keytool", "-import", "-noprompt", "-file", 
                littleProxyCert.getName(), 
                "-alias", "littleproxy", "-keystore", 
                TRUSTSTORE_FILE.getAbsolutePath(), "-storepass",  PASS);
        } else {
            log.warn("NO LITTLEPROXY CERT FILE TO IMPORT!!");
        }
        
        this.lanternTrustManager = 
            new LanternTrustManager(this, TRUSTSTORE_FILE, PASS);
        
        trustManagers = new TrustManager[] {
            lanternTrustManager
        };
    }
    

    private void createTrustStore() {
        if (TRUSTSTORE_FILE.isFile()) {
            log.info("Trust store already exists");
            return;
        }
        
        CommonUtils.nativeCall("keytool", "-genkey", "-alias", "foo", "-keysize", 
            "1024", "-validity", "36500", "-keyalg", "DSA", "-dname", 
            "CN="+LanternUtils.getMacAddress(), "-keystore", 
            TRUSTSTORE_FILE.getAbsolutePath(), "-keypass", PASS, 
            "-storepass", PASS);
    }

    private void reset(final String macAddress) {
        log.info("RESETTING KEYSTORE AND TRUSTSTORE!!");
        /*
        if (KEYSTORE_FILE.isFile()) {
            System.out.println("Deleting existing keystore file at: " +
                KEYSTORE_FILE.getAbsolutePath());
            KEYSTORE_FILE.delete();
        }
        */
        
        if (TRUSTSTORE_FILE.isFile()) {
            System.out.println("Deleting existing truststore file at: " +
                TRUSTSTORE_FILE.getAbsolutePath());
            TRUSTSTORE_FILE.delete();
        }
    
        // Note we use DSA instead of RSA because apparently only the JDK 
        // has RSA available.
        /*
        CommonUtils.nativeCall("keytool", "-genkey", "-alias", macAddress, 
            "-keysize", "1024", "-validity", "36500", "-keyalg", "DSA", 
            "-dname", "CN="+macAddress, "-keypass", PASS, "-storepass", 
            PASS, "-keystore", KEYSTORE_FILE.getAbsolutePath());
        
        waitForFile(KEYSTORE_FILE);
        
        // Now grab our newly-generated cert. All of our trusted peers will
        // use this to connect.
        CommonUtils.nativeCall("keytool", "-exportcert", "-alias", macAddress, 
            "-keystore", KEYSTORE_FILE.getAbsolutePath(), "-storepass", PASS, 
            "-file", CERT_FILE.getAbsolutePath());
        
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

        log.info("Creating trust store");
        */
        createTrustStore();
        
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

    /*
    public String getBase64Cert() {
        return localCert;
    }
    */

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
            throw new Error("Could not find keystore file!!");
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
        return trustManagers;
    }
}
