import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.Writer;
import java.net.URL;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

import javax.net.ssl.HttpsURLConnection;

public class InstallDownloader {

    public static boolean verify(final File dir) throws IOException {
        log("Downloading from file: "+dir.getAbsolutePath());
        final String fileName;
        final String os = System.getProperty("os.name");
        if (os.startsWith("Windows")) {
            fileName = "latest.exe.sha1";
        } else if (os.startsWith("Mac OS X")) {
            fileName = "latest.dmg.sha1";
        } else if (os.startsWith("Linux") || os.startsWith("LINUX")) {
            final String arch = System.getProperty("os.arch");
            if (arch.contains("64")) {
                fileName = "latest-64.deb.sha1";
            } else {
                fileName = "latest-32.deb.sha1";
            }
        } else {
            return false;
        }
        final String hash = downloadHash(fileName);
        log("Donnloaded: '"+hash+"'");
        log("CUR DIR: "+System.getProperty("user.dir"));
        final String localName;
        final String parsed = fileName.substring(0, fileName.length()-5);
        if (parsed.endsWith(".deb")) {
            localName = "latest.deb";
        } else {
            localName = parsed;
        }
        final File file = new File(dir, localName);
        //final File file = new File(fileName.substring(0, fileName.length()-5));
        log("NAME "+file.getName());
        log("SIZE: "+file.length());
        InputStream is = null;
        try {
            is = new FileInputStream(file);
            final String sha1 = sha1(is, (int) file.length());
            if (sha1.equals(hash)) {
                log("SHA-1s MATCH!!");
                return true;
            }
            
            log("SHAS DON'T MATCH!! SHA: '"+sha1+"'");
        } catch (final FileNotFoundException e1) {
            e1.printStackTrace();
        } finally {
            try {is.close();} catch (IOException e) {}
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
        final byte[] buffer = new byte[size];
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

    private static String downloadHash(final String fileName) throws IOException {
        
        final String str = "https://s3.amazonaws.com/lantern/"+fileName;
        log("downloading: "+str);
        final URL url = new URL(str);
        final HttpsURLConnection conn = (HttpsURLConnection) url.openConnection();
        conn.setConnectTimeout(200*1000);
        conn.setReadTimeout(200*1000);
        
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
            e.printStackTrace();
        } finally {
            if (is != null) {
                try {is.close();} catch (IOException e) {}
            }
        }
        return "";
    }

    public static final File CONFIG_DIR =
            new File(System.getProperty("user.home"), ".lantern");
    
    private static void log(final String string) {
        if (!CONFIG_DIR.isDirectory()) {
            CONFIG_DIR.mkdirs();
        }
        final File log = new File(CONFIG_DIR, 
                "lantern-verify-installer-log.txt");
        Writer os = null;
        try {
            os = new FileWriter(log, true);
            os.append(string + "\n");
        } catch (final IOException e) {
            e.printStackTrace();
        } finally {
            if (os != null) {
                try {os.close();} catch (IOException e) {}
            }
        }
    }
}
