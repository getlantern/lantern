package org.mg.client;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Arrays;

import javax.net.ssl.TrustManager;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.lastbamboo.common.util.FileUtils;
import org.littleshoot.proxy.KeyStoreManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


public class LanternKeyStoreManager implements KeyStoreManager {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File CONFIG_DIR = LanternUtils.configDir();
    
    private final File KEYSTORE_FILE = 
        new File(CONFIG_DIR, "lantern_keystore.jks");
    
    private final File TRUSTSTORE_FILE = 
        new File(CONFIG_DIR, "lantern_truststore.jks");
    
    private final File CERT_FILE = 
        new File(CONFIG_DIR, "local_lantern_cert");
    
    private static final String PASS = "Be Your Own Lantern";

    private String localCert;
    
    private final TrustManager[] trustManagers;

    public LanternKeyStoreManager() {
        this(true);
    }
    
    public LanternKeyStoreManager(final boolean regenerate) {
        if(regenerate) {
            reset(LanternUtils.getMacAddress());
        }
        createTrustStore();
        final File littleProxyCert = new File("lantern_littleproxy_cert");
        if (littleProxyCert.isFile()) {
            log.info("Importing cert");
            nativeCall("keytool", "-import", "-noprompt", "-file", 
                littleProxyCert.getName(), 
                "-alias", "littleproxy", "-keystore", 
                TRUSTSTORE_FILE.getAbsolutePath(), "-storepass",  PASS);
        } else {
            log.warn("NO LITTLEPROXY CERT FILE TO IMPORT!!");
        }
        
        trustManagers = new TrustManager[] {
            new LanternTrustManager(this)
        };
    }
    

    private void createTrustStore() {
        if (TRUSTSTORE_FILE.isFile()) {
            log.info("Trust store already exists");
            return;
        }
        
        nativeCall("keytool", "-genkey", "-alias", "foo", "-keysize", 
            "1024", "-validity", "36500", "-keyalg", "DSA", "-dname", 
            "CN="+LanternUtils.getMacAddress(), "-keystore", 
            TRUSTSTORE_FILE.getAbsolutePath(), "-keypass", PASS, 
            "-storepass", PASS);
    }

    private void reset(final String macAddress) {
        log.info("RESETTING KEYSTORE AND TRUSTSTORE!!");
        if (KEYSTORE_FILE.isFile()) {
            System.out.println("Deleting existing keystore file at: " +
                KEYSTORE_FILE.getAbsolutePath());
            KEYSTORE_FILE.delete();
        }
        
        if (TRUSTSTORE_FILE.isFile()) {
            System.out.println("Deleting existing truststore file at: " +
                TRUSTSTORE_FILE.getAbsolutePath());
            TRUSTSTORE_FILE.delete();
        }
    
        // Note we use DSA instead of RSA because apparently only the JDK 
        // has RSA available.
        nativeCall("keytool", "-genkey", "-alias", macAddress, "-keysize", 
            "1024", "-validity", "36500", "-keyalg", "DSA", "-dname", 
            "CN="+macAddress, "-keypass", PASS, "-storepass", 
            PASS, "-keystore", KEYSTORE_FILE.getAbsolutePath());
        
        // Now grab our newly-generated cert. All of our trusted peers will
        // use this to connect.
        nativeCall("keytool", "-exportcert", "-alias", macAddress, "-keystore", 
            KEYSTORE_FILE.getAbsolutePath(), "-storepass", PASS, "-file", 
            CERT_FILE.getAbsolutePath());
        
        try {
            final InputStream is = new FileInputStream(CERT_FILE);
            localCert = Base64.encodeBase64String(IOUtils.toByteArray(is));
        } catch (final FileNotFoundException e) {
            log.error("Cert file not found?", e);
            throw new Error("Cert file not found", e);
        } catch (final IOException e) {
            log.error("Could not base 64 encode cert?", e);
            throw new Error("Could not base 64 encode cert?", e);
        }

        log.info("Creating trust store");
        createTrustStore();
        
        /*
        log.info("Importing cert");
        nativeCall("keytool", "-import", "-noprompt", "-file", CERT_FILE.getName(), 
            "-alias", AL, "-keystore", TRUSTSTORE_FILE.getName(), "-storepass", 
            PASS);
            */

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
        nativeCall("keytool", "-delete", "-alias", fileName, 
            "-keystore", TRUSTSTORE_FILE.getAbsolutePath(), "-storepass", PASS);
        
        nativeCall("keytool", "-importcert", "-noprompt", "-alias", fileName, 
            "-keystore", TRUSTSTORE_FILE.getAbsolutePath(), 
            "-file", certFile.getAbsolutePath(), 
            "-keypass", PASS, "-storepass", PASS);
    }


    private String nativeCall(final String... commands) {
        log.info("Running '{}'", Arrays.asList(commands));
        final ProcessBuilder pb = new ProcessBuilder(commands);
        try {
            final Process process = pb.start();
            final InputStream is = process.getInputStream();
            final String data = IOUtils.toString(is);
            log.info("Completed native call: '{}'\nResponse: '"+data+"'", 
                Arrays.asList(commands));
            final int ev = process.exitValue();
            if (ev != 0) {
                final String msg = "Process not completed normally! " + 
                    Arrays.asList(commands)+" Exited with: "+ev;
                System.err.println(msg);
                log.error(msg);
            } else {
                log.info("Process completed normally!");
            }
            return data;
        } catch (final IOException e) {
            log.error("Error running commands: " + Arrays.asList(commands), e);
            return "";
        }
    }

    public TrustManager[] getTrustManagers() {
        return trustManagers;
    }
}
