package org.lantern.launcher;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.security.NoSuchProviderException;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;

public class TestLoading {

    public static X509Certificate loadCert() throws IOException, CertificateException, NoSuchProviderException {
        String systemLantern = System.getProperty("user.dir");

        InputStream is = new FileInputStream(new File(systemLantern,
                "publicCert.cer"));
        CertificateFactory factory = CertificateFactory.getInstance("X.509");

        /*
         * Generate a X509 Certificate initialized with the data read from the
         * input stream.
         */
        X509Certificate cert = (X509Certificate) factory
                .generateCertificate(is);

        return cert;
    }

    public static void main(String[] args) throws ClassNotFoundException,
            SecurityException, NoSuchMethodException, IllegalArgumentException,
            InstantiationException, IllegalAccessException,
            InvocationTargetException, CertificateException,
            NoSuchProviderException, IOException {

        //String myJar = "file:/home/leah/lantern/test/unsigned.jar";
        //String myJar = "file:/home/leah/lantern/test/bad2.jar";
        String myJar = "file:/home/leah/lantern/test/good.jar";
        SignatureCheckingJarLoader loader = new SignatureCheckingJarLoader(myJar, null);
        loader.setAcceptedCertificate(loadCert());
        loader.readJarFile();

        Class<?> cls = loader.loadClass("LXSExample");

        if (cls != null) {
            System.out.println("ok, loaded");
            Constructor<?> ctor = cls.getConstructors()[0];
            Object obj = ctor.newInstance();
            Method method = cls.getMethod("foo");
            method.invoke(obj);
        }

    }
}
