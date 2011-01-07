package org.mg.client;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;
import java.util.Arrays;
import java.util.zip.GZIPInputStream;
import java.util.zip.GZIPOutputStream;

import javax.net.ssl.TrustManager;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.lastbamboo.common.util.FileUtils;
import org.littleshoot.proxy.KeyStoreManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LanternKeyStoreManager implements KeyStoreManager {
    
    private final Logger log = 
        LoggerFactory.getLogger(LanternKeyStoreManager.class);
    
    private final File KEYSTORE_FILE = new File("lantern_keystore.jks");
    
    private final File TRUSTSTORE_FILE = new File("lantern_truststore.jks");
    
    private final File CERT_FILE = new File("lantern_cert");
    
    private final String AL = "lantern";
    
    private static final String PASS = "Be Your Own Lantern";

    private final String CERT;
    
    private final TrustManager[] trustManagers = {
        new LanternTrustManager(this)
    };
    
    public LanternKeyStoreManager() {
        this(true);
    }
    
    public LanternKeyStoreManager(final boolean regenerate) {
        //PASS = String.valueOf(RandomUtils.nextLong());
        System.out.println("PASSWORD: "+PASS);
        
        if (regenerate) {
            resetStores();
        }

        final File littleProxyCert = new File("lantern_littleproxy_cert");
        if (littleProxyCert.isFile()) {
            log.info("Importing cert");
            nativeCall("keytool", "-import", "-noprompt", "-file", 
                littleProxyCert.getName(), 
                "-alias", "littleproxy", "-keystore", 
                TRUSTSTORE_FILE.getName(), "-storepass",  PASS);
        } else {
            log.warn("NO LITTLEPROXY CERT FILE TO IMPORT!!");
        }

        try {
            final InputStream is = new FileInputStream(CERT_FILE);
            
            // Compress it to save bandwidth.
            final ByteArrayOutputStream baos = new ByteArrayOutputStream();
            //final GZIPOutputStream gout = new GZIPOutputStream(baos);
            //IOUtils.copy(is, gout);
            
            //CERT = Base64.encodeBase64URLSafeString(IOUtils.toByteArray(is));
            CERT = IOUtils.toString(is);
        } catch (final FileNotFoundException e) {
            log.error("Cert file not found?", e);
            throw new Error("Cert file not found", e);
        } catch (final IOException e) {
            log.error("Could not base 64 encode cert?", e);
            throw new Error("Could not base 64 encode cert?", e);
        }
    }
    
    private void resetStores() {
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
        nativeCall("keytool", "-genkey", "-alias", AL, "-keysize", 
            "1024", "-validity", "36500", "-keyalg", "DSA", "-dname", 
            "CN=lantern", "-keypass", PASS, "-storepass", 
            PASS, "-keystore", KEYSTORE_FILE.getName());
        
        // Now grab our newly-generated cert. All of our trusted peers will
        // use this to connect.
        nativeCall("keytool", "-exportcert", "-alias", AL, "-keystore", 
            KEYSTORE_FILE.getName(), "-storepass", PASS, "-file", 
            CERT_FILE.getName());

        log.info("Creating trust store");
        
        nativeCall("keytool", "-genkey", "-alias", "foo", "-keysize", 
                "1024", "-validity", "36500", "-keyalg", "DSA", "-dname", 
                "CN=lantern", "-keystore", 
            TRUSTSTORE_FILE.getName(), "-keypass", PASS, "-storepass", PASS);
        
        /*
        log.info("Importing cert");
        nativeCall("keytool", "-import", "-noprompt", "-file", CERT_FILE.getName(), 
            "-alias", AL, "-keystore", TRUSTSTORE_FILE.getName(), "-storepass", 
            PASS);
            */
    }

    public String getBase64Cert() {
        return CERT;
    }

    public InputStream keyStoreAsInputStream() {
        try {
            return new FileInputStream(KEYSTORE_FILE);
        } catch (final FileNotFoundException e) {
            throw new Error("Could not find keystore file!!");
        }
    }
    
    public InputStream trustStoreAsInputStream() {
        try {
            return new FileInputStream(TRUSTSTORE_FILE);
        } catch (final FileNotFoundException e) {
            throw new Error("Could not find keystore file!!");
        }
    }

    public char[] getCertificatePassword() {
        return PASS.toCharArray();
    }

    public char[] getKeyStorePassword() {
        return PASS.toCharArray();
    }
    
    public void addBase64Cert(final URI uri, final String base64Cert) 
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
        //final GZIPInputStream gzip = 
        //    new GZIPInputStream(new ByteArrayInputStream(decoded));
        final String fileName = normalizeName(uri);
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
        
        nativeCall("keytool", "-importcert", "-alias", AL, "-keystore", 
            TRUSTSTORE_FILE.getName(), "-file", certFile.getName(), 
            "-keypass", PASS, "-storepass", PASS);
    }

    private String normalizeName(final URI uri) {
        final String full = uri.toASCIIString();
        return FileUtils.removeIllegalCharsFromFileName(full);
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
