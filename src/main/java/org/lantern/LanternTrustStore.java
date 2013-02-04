package org.lantern;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.security.SecureRandom;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.littleshoot.util.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LanternTrustStore {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private static final String KEYSIZE = "2048";
    
    private static final String PASS = 
        String.valueOf(new SecureRandom().nextLong());
    
    private static final String ALG = "RSA";
    
    private static final File TRUSTSTORE_FILE = 
        new File(LanternConstants.CONFIG_DIR, 
            String.valueOf(new SecureRandom().nextLong()));
    
    private final CertTracker certTracker;
    
    public LanternTrustStore(final CertTracker certTracker) {
        this.certTracker = certTracker;
        configureTrustStore();
    }

    public void addBase64Cert(final String fullJid, final String base64Cert) 
        throws IOException {
        log.debug("Adding base 64 cert");
        this.certTracker.addCert(base64Cert, fullJid);
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
            FileUtils.removeIllegalCharsFromFileName(fullJid);
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
        // Make sure we delete the old one (will fail when it doesn't exist -
        // this is expected).
        final String deleteResult = LanternUtils.runKeytool("-delete", 
            "-alias", normalizedAlias, "-keystore", 
            TRUSTSTORE_FILE.getAbsolutePath(), "-storepass", PASS);
        log.debug("Result of deleting old cert: {}", deleteResult);
        
        
        // TODO: We should be able to just add it to the trust store here 
        // without saving
        
        addCert(normalizedAlias, certFile);
        
        /*
        // TODO: Check importcert versus straight import.
        final String importResult = LanternUtils.runKeytool("-importcert", 
            "-noprompt", "-alias", normalizedAlias, "-keystore", 
            TRUSTSTORE_FILE.getAbsolutePath(), 
            "-file", certFile.getAbsolutePath(), 
            "-keypass", PASS, "-storepass", PASS);
        log.debug("Result of importing new cert: {}", importResult);
        */
        
        // We need to reload the keystore with the latest data.
        //this.trustStore = loadTrustStore();
        
        // get rid of our imported file
        certFile.delete();
        certFile.deleteOnExit();
    }

    
    private void configureTrustStore() {
        TRUSTSTORE_FILE.delete();
        TRUSTSTORE_FILE.deleteOnExit();
        createTrustStore();
        addStaticCerts();
        System.setProperty("javax.net.ssl.trustStore", 
                TRUSTSTORE_FILE.getAbsolutePath());
    }
    
    private void createTrustStore() {
        if (TRUSTSTORE_FILE.isFile()) {
            log.info("Trust store already exists");
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
        addCert("littleproxy", "certs/littleporxy.cer");
        addCert("equifaxsecureca", "certs/equifaxsecureca.cer");
    }

    private void addCert(final String alias, final String fileName) {
        final File cert = new File(fileName);
        addCert(alias, cert);
    }

    private void addCert(final String alias, final File cert) {
        if (!cert.isFile()) {
            log.error("No cert at "+cert);
            System.exit(1);
        }
        log.debug("Importing cert");
        final String result = LanternUtils.runKeytool("-import", 
            "-noprompt", "-file", cert.getName(), 
            "-alias", alias, "-keystore", 
            TRUSTSTORE_FILE.getAbsolutePath(), "-storepass", PASS);
        
        log.debug("Result of running keytool: {}", result);
    }

    public String getTrustStorePath() {
        return TRUSTSTORE_FILE.getAbsolutePath();
    }

    public String getTrustStorePassword() {
        return PASS;
    }
}
