/**
 *  Based on code from Java Security, by Scott Oaks, published by O'Reilly
 */
package org.lantern.launcher;

import java.io.BufferedInputStream;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.nio.channels.Channels;
import java.security.CodeSource;
import java.security.SecureClassLoader;
import java.security.cert.Certificate;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.Map;
import java.util.jar.JarEntry;
import java.util.jar.JarInputStream;

public class SignatureCheckingJarLoader extends SecureClassLoader {
    protected URL urlBase;
    protected Map<String, byte[]> classBuffers = new HashMap<String, byte[]>();
    protected Map<String, byte[]> resourceBuffers = new HashMap<String, byte[]>();
    protected Map<String, Certificate[]> classIds = new HashMap<String, Certificate[]>();
    protected Certificate acceptedCertificate;

    public SignatureCheckingJarLoader(String base, ClassLoader parent) {
        super(parent);
        try {
            urlBase = new URL("file:" + base);
        } catch (Exception e) {
            throw new IllegalArgumentException(base, e);
        }
    }

    public void setAcceptedCertificate(Certificate acceptedCert) {
        this.acceptedCertificate = acceptedCert;
    }

    @Override
    protected Class<?> findClass(String name) {
        String urlName = name.replace('.', '/');
        Class<?> cl;

        byte[] buf = classBuffers.get(urlName);
        if (buf == null) {
           return null;
        }
        Certificate ids[] = classIds.get(urlName);
        CodeSource cs = new CodeSource(urlBase, ids);
        cl = defineClass(name, buf, 0, buf.length, cs);
        return cl;

    }

    @Override
    public URL getResource(String resource) {
        throw new RuntimeException("There is no way to make getResource() " +
                "secure, because it returns a URL that could be opened " +
                "without certificate checking.  Use getResourceAsStream()");
    }

    @Override
    public Enumeration<URL> getResources(String name) {
        throw new RuntimeException("There is no way to make getResources() " +
                "secure, because it returns URLs that could be opened " +
                "without certificate checking.  Use getResourceAsStream()");
    }

    @Override
    public InputStream getResourceAsStream(String name) {
        byte[] buffer = resourceBuffers.get(name);
        if (buffer == null) {
            return null;
        }
        return new ByteArrayInputStream(buffer);
    }

    public void readJarFile() throws MalformedURLException, IOException {
        JarInputStream jis = new JarInputStream(urlBase.openConnection()
                .getInputStream());

        try {
            JarEntry je;
            while ((je = jis.getNextJarEntry()) != null) {
                if (je.isDirectory()) {
                    continue;
                }
                loadBytes(jis, je.getName(), je);
                jis.closeEntry();
            }
        } catch (IOException ioe) {
            System.err.println("Badly formatted jar file");
        }
    }

    private void assertSignedByAcceptedCert(Certificate[] certs) {
        for (Certificate cert : certs) {
            if (cert.equals(acceptedCertificate)) {
                return;
            }
        }

        throw new SecurityException("The jar entry is not signed by us");
    }

    private byte[] inputStreamToByteArray(InputStream is) {
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        BufferedInputStream buffered = new BufferedInputStream(is);
        try {
            int read;
            while ((read = buffered.read()) != -1) {
                outputStream.write(read);
            }
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return outputStream.toByteArray();
    }

    public static X509Certificate loadCert(File file ) {
        try {
            InputStream is = new FileInputStream(file);
            CertificateFactory factory = CertificateFactory.getInstance(
                    "X.509");

            X509Certificate cert = (X509Certificate) factory
                    .generateCertificate(is);

            return cert;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private void loadBytes(JarInputStream jis, String jarName, JarEntry je) {
        Channels.newChannel(jis);

        byte[] buffer = inputStreamToByteArray(jis);

        Certificate c[] = null;
        if (!jarName.startsWith("META-INF/")) {
            //don't check items in META-INF, because they won't be signed

            c = je.getCertificates();
            if (c == null)
                throw new SecurityException("Jar object " + jarName
                    + " is not signed");
            assertSignedByAcceptedCert(c);
        }
        if (jarName.endsWith(".class")) {
            String className = jarName.substring(0,
                    jarName.length() - ".class".length());
            classBuffers.put(className, buffer);
            classIds.put(className, c);
        } else {
            resourceBuffers.put(jarName, buffer);
        }
    }

}