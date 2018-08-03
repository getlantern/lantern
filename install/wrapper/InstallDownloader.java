import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.io.Writer;
import java.net.URL;
import java.security.KeyManagementException;
import java.security.KeyStoreException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.cert.CertificateException;
import java.text.SimpleDateFormat;
import java.util.Date;

import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLSocketFactory;

public class InstallDownloader {
    
    private static final int MAX_SHA1_TRIES = 10;
    
    public static boolean verify(final File dir) 
            throws IOException {
        log("Downloading from file: "+dir.getAbsolutePath());
        final String fileName;
        final String os = System.getProperty("os.name");
        if (os.startsWith("Windows")) {
            fileName = "newest.exe.sha1";
        } else if (os.startsWith("Mac OS X")) {
            fileName = "newest.dmg.sha1";
        } else if (os.startsWith("Linux") || os.startsWith("LINUX")) {
            final String arch = System.getProperty("os.arch");
            if (arch.contains("64")) {
                fileName = "newest-64.deb.sha1";
            } else {
                fileName = "newest-32.deb.sha1";
            }
        } else {
            return false;
        }
        final String hash;
        try {
            hash = downloadHash(fileName, 0);
        } catch (final Exception e) {
            log("Could not download hash!! "+e.getMessage());
            return false;
        }
        log("Downloaded: '"+hash+"'");
        log("CUR DIR: "+System.getProperty("user.dir"));
        final String localName;
        
        // Just strip the SHA-1 from the calculated name above.
        final String parsed = fileName.substring(0, fileName.length()-5);
        if (parsed.endsWith(".deb")) {
            localName = "newest.deb";
        } else {
            localName = parsed;
        }
        final File file = new File(dir, localName);
        
        final long now = System.currentTimeMillis();
        
        final long elapsed = now - file.lastModified();
        
        log("ELAPSED TIME SINCE DOWNLOAD: "+elapsed);
        if (elapsed > 1000 * 60) {
            log("LAST MODIFIED TIME OF DOWNLOADED FILE TOO FAR IN THE PAST!!");
        }
        //final File file = new File(fileName.substring(0, fileName.length()-5));
        log("NAME "+file.getName());
        log("SIZE: "+file.length());
        log("EXISTS: "+file.isFile());
        InputStream is = null;
        try {
            is = new FileInputStream(file);
            final String sha1 = sha1(is, (int) file.length());
            if (sha1.equals(hash)) {
                log("SHA-1s MATCH!!");
                //return launchInstaller(file, installDir);
                return true;
            }
            
            log("SHAS DON'T MATCH!! SHA: '"+sha1+"'");
        } catch (final FileNotFoundException e1) {
            log("Could not find file at all? "+e1.getMessage());
        } finally {
            if (is != null) {try {is.close();} catch (IOException e) {}};
        }
        return false;
    }
    
    private static boolean launchInstaller(final File dmg, final File installDir) {
        log("Launching installer...");
        log("Current directory is: "+System.getProperty("user.dir"));
        final ProcessBuilder builder = new ProcessBuilder("./installdmg.bash", 
                "\""+dmg.getAbsolutePath()+"\"");
        builder.directory(installDir);
        try {
            final Process process = builder.start();
            final InputStream is = process.getInputStream();
            final InputStreamReader isr = new InputStreamReader(is);
            final BufferedReader br = new BufferedReader(isr);
            String line;
            while ((line = br.readLine()) != null) {
              log("Script output: "+line);
            }
            final int exit = process.waitFor();
            if (exit == 0) {
                return true;
            }
            return false;
        } catch (IOException e) {
            log("Could not run script:\n"+dumpStack(e));
        } catch (InterruptedException e) {
            log("Could not run script:\n"+dumpStack(e));
        }
        return false;
    }

    private static String sha1(final InputStream is, final int size)
            throws IOException {
        final MessageDigest md;
        try {
             md = MessageDigest.getInstance("SHA-1");
            
        } catch (final NoSuchAlgorithmException e) {
            return "";
        }
        final byte[] buffer = new byte[65536];
        int read;
        try {
            while ((read = is.read(buffer)) != -1) {
                md.update(buffer, 0, read);
            }
        } finally {
            try {is.close();} catch (IOException e) {}
        }

        final byte[] sha1 = md.digest();
        return bytesToHex(sha1);
    }
    
    private final static char[] hexArray = 
        {'0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'};
    private static String bytesToHex(final byte[] bytes) {
        final char[] hexChars = new char[bytes.length * 2];
        int v;
        for ( int j = 0; j < bytes.length; j++ ) {
            v = bytes[j] & 0xFF;
            hexChars[j * 2] = hexArray[v >>> 4];
            hexChars[j * 2 + 1] = hexArray[v & 0x0F];
        }
        return new String(hexChars);
    }

    private static String downloadHash(final String fileName, int tries) 
            throws Exception {
        
        final String str = "https://s3.amazonaws.com/lantern/"+fileName;
        log("downloading: "+str);
        final URL url = new URL(str);
        final HttpsURLConnection conn = (HttpsURLConnection) url.openConnection();
        conn.setConnectTimeout(200*1000);
        conn.setReadTimeout(200*1000);
        conn.setSSLSocketFactory(newAwsSocketFactory());
        conn.setUseCaches(false);
        
        InputStream is = null;
        try {
            is = conn.getInputStream();
            final StringBuilder sb = new StringBuilder();
            int cur = is.read();
            while (cur != -1) {
                sb.append((char)cur);
                cur = is.read();
            }
            return sb.toString().trim();
        } catch (final IOException e) {
            if (tries > MAX_SHA1_TRIES) {
                log("Download failed after "+tries+" tries!!");
                throw e;
            } else {
                log("Could not download? "+e.getMessage()+"\n"+dumpStack(e));
                try {
                    Thread.sleep(600);
                } catch (final InterruptedException e1) {
                }
                downloadHash(fileName, tries++);
            }
        } finally {
            if (is != null) {
                try {is.close();} catch (IOException e) {}
            }
        }
        log("Still could not download???");
        return "";
    }

    /**
     * Creates an SSL socket factory that only trusts verisign.
     */
    private static SSLSocketFactory newAwsSocketFactory() throws 
        NoSuchAlgorithmException, KeyManagementException, KeyStoreException, 
        CertificateException, IOException {
        log("Using default socket factory...");
        return (SSLSocketFactory) SSLSocketFactory.getDefault();
        //final SSLContext ctx = SSLContext.getInstance("TLS");
        //ctx.init(null, tmf.getTrustManagers(), null);
        //return ctx.getSocketFactory();
        
        /*
        log("Generating SSLSocketFactory for Amazon/verisign");
        final KeyStore ks = KeyStore.getInstance("JKS"); 
        ks.load( null, null );
        final CertificateFactory cf = CertificateFactory.getInstance( "X.509" );
        final InputStream bis = 
            new ByteArrayInputStream(verisign.getBytes(Charset.forName("UTF-8")));
        final Certificate cert = cf.generateCertificate(bis);
        ks.setCertificateEntry("verisign", cert);
        
        final TrustManagerFactory tmf = 
                TrustManagerFactory.getInstance(
                    TrustManagerFactory.getDefaultAlgorithm());
        tmf.init(ks);
        final SSLContext ctx = SSLContext.getInstance("TLS");
        ctx.init(null, tmf.getTrustManagers(), null);
        return ctx.getSocketFactory();
        */
    }

    public static final File CONFIG_DIR =
            new File(System.getProperty("user.home"), ".lantern");
    
    private static void log(final String string) {
        if (!CONFIG_DIR.isDirectory()) {
            CONFIG_DIR.mkdirs();
        }
        final File log = new File(CONFIG_DIR, 
                "lantern-verify-installer-log.txt");
        
        final SimpleDateFormat df = new SimpleDateFormat("yyyy.MM.dd 'at' HH:mm:ss z");
        final String formatted = df.format(new Date());
        Writer os = null;
        try {
            os = new FileWriter(log, true);
            os.append(formatted);
            os.append(": ");
            os.append(string + "\n");
        } catch (final IOException e) {
            e.printStackTrace();
        } finally {
            if (os != null) {
                try {os.close();} catch (IOException e) {}
            }
        }
    }
    

    /**
     * Verisign is the CA for S3 certs.
     */
    private static final String verisign =
        "-----BEGIN CERTIFICATE-----\n"+
        "MIIE+DCCA+CgAwIBAgIQeo+SIwIaV15+swESSrlhUDANBgkqhkiG9w0BAQUFADCB\n"+
        "tTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQL\n"+
        "ExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTswOQYDVQQLEzJUZXJtcyBvZiB1c2Ug\n"+
        "YXQgaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL3JwYSAoYykwOTEvMC0GA1UEAxMm\n"+
        "VmVyaVNpZ24gQ2xhc3MgMyBTZWN1cmUgU2VydmVyIENBIC0gRzIwHhcNMTAxMDA4\n"+
        "MDAwMDAwWhcNMTMxMDA3MjM1OTU5WjBpMQswCQYDVQQGEwJVUzETMBEGA1UECBMK\n"+
        "V2FzaGluZ3RvbjEQMA4GA1UEBxQHU2VhdHRsZTEYMBYGA1UEChQPQW1hem9uLmNv\n"+
        "bSBJbmMuMRkwFwYDVQQDFBBzMy5hbWF6b25hd3MuY29tMIGfMA0GCSqGSIb3DQEB\n"+
        "AQUAA4GNADCBiQKBgQDJccYKRvRt1Dq99i1G21g6UVMTm0ePye9sw2FtTYsOtAcx\n"+
        "2MEMO12W89ryqxjrJfW0Z8bCqw3HUv9cRczjxO+l5de6lnaMZUZNWGhA/Z0ajjzV\n"+
        "P59JKJu4I4zJf74N85hG99HB2t2oCw0cSJVoVQupZP0OUYoYLbxvO/v5UO0H5wID\n"+
        "AQABo4IB0TCCAc0wCQYDVR0TBAIwADALBgNVHQ8EBAMCBaAwRQYDVR0fBD4wPDA6\n"+
        "oDigNoY0aHR0cDovL1NWUlNlY3VyZS1HMi1jcmwudmVyaXNpZ24uY29tL1NWUlNl\n"+
        "Y3VyZUcyLmNybDBEBgNVHSAEPTA7MDkGC2CGSAGG+EUBBxcDMCowKAYIKwYBBQUH\n"+
        "AgEWHGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9ycGEwHQYDVR0lBBYwFAYIKwYB\n"+
        "BQUHAwEGCCsGAQUFBwMCMB8GA1UdIwQYMBaAFKXvCxHOwEEDo0plkEiyHOBXLX1H\n"+
        "MHYGCCsGAQUFBwEBBGowaDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AudmVyaXNp\n"+
        "Z24uY29tMEAGCCsGAQUFBzAChjRodHRwOi8vU1ZSU2VjdXJlLUcyLWFpYS52ZXJp\n"+
        "c2lnbi5jb20vU1ZSU2VjdXJlRzIuY2VyMG4GCCsGAQUFBwEMBGIwYKFeoFwwWjBY\n"+
        "MFYWCWltYWdlL2dpZjAhMB8wBwYFKw4DAhoEFEtruSiWBgy70FI4mymsSweLIQUY\n"+
        "MCYWJGh0dHA6Ly9sb2dvLnZlcmlzaWduLmNvbS92c2xvZ28xLmdpZjANBgkqhkiG\n"+
        "9w0BAQUFAAOCAQEAer6KWnbs08+ZIAtj0eI9wq85KLj/NKuw9EZDgPDfO5vwfP7D\n"+
        "TKEhq8SDhTcRI+zr5FH28ev6ifio1ixFujbnTNDBryPfbzkIZvE7gahmzOYyZEOo\n"+
        "SaD4JDHqRQkVNZQMy3107tB7g/seSAEkQo6o5BVuKKEobGR8z4YFXAdq4Mg9ZoC1\n"+
        "WTBoIvQUMoM/ckIf9wRmiPgPSyTpMqFPE0pkTyJGfICrvcJbYN1XVqgHHZY5lbOw\n"+
        "JFoEknD6Zo6EMze/VVMewpseiHUT4DvBn/gtXMhEc/87QQ5ml9u+r+9QT+UjdI5w\n"+
        "W4wWQZ5AWPUZmZ4Dl8XgUPtCeArv8R+9zQVMHQ==\n"+
        "-----END CERTIFICATE-----";
    
    private static String dumpStack() {
        return dumpStack(new Exception("Stack Dump Generated Exception"));
    }

    /**
     * Returns the stack trace as a string.
     * 
     * @param cause The thread to dump.
     * @return The stack trace as a string.
     */
    private static String dumpStack(final Throwable cause) {
        if (cause == null) {
            return "Throwable was null";
        }
        final StringWriter sw = new StringWriter();
        final PrintWriter s = new PrintWriter(sw);

        // This is very close to what Thread.dumpStack does.
        cause.printStackTrace(s);

        final String stack = sw.toString();
        try {
            sw.close();
        } catch (final IOException e) {
            log("Could not close writer\n"+dumpStack(e));
        }
        s.close();
        return stack;
    }
    
    /*
    public static void main(final String[] args) {
        
        // Verify we can connect to amazon but will reject Google!
        try {
            final SSLSocketFactory sslFactory = InstallDownloader.newAwsSocketFactory();
            final SSLSocket amazon = (SSLSocket) sslFactory.createSocket("s3.amazonaws.com", 443);
            amazon.getOutputStream().write("hello".getBytes(Charset.forName("UTF-8")));
            amazon.close();
            System.err.println("SAID HELLO TO AMAZON");
            
            final SSLSocket google = (SSLSocket) sslFactory.createSocket("google.com", 443);
            google.getOutputStream().write("hello".getBytes(Charset.forName("UTF-8")));
            google.close();
            
        } catch (KeyManagementException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        } catch (NoSuchAlgorithmException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        } catch (KeyStoreException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        } catch (CertificateException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        } catch (IOException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
    }
    */
}
