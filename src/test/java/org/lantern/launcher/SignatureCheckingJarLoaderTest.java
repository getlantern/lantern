package org.lantern.launcher;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.MalformedURLException;
import java.net.URL;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;

import org.junit.Test;

public class SignatureCheckingJarLoaderTest {

    @Test
    public void testLoader() throws CertificateException,
            MalformedURLException, IOException, ClassNotFoundException,
            IllegalArgumentException, InstantiationException,
            IllegalAccessException, InvocationTargetException,
            SecurityException, NoSuchMethodException {
        ClassLoader classLoader = getClass().getClassLoader();
        String certFile = classLoader.getResource("test_cert.der").getFile();

        InputStream is = new FileInputStream(certFile);
        CertificateFactory factory = CertificateFactory.getInstance("X.509");
        X509Certificate cert = (X509Certificate) factory
                .generateCertificate(is);

        URL resource = classLoader.getResource("unsigned.jar");
        SignatureCheckingJarLoader loader = new SignatureCheckingJarLoader(
                resource.getFile(), null);
        loader.setAcceptedCertificate(cert);
        boolean exceptionCaught = false;
        try {
            loader.readJarFile();
        } catch (SecurityException e) {
            exceptionCaught = true;
        }
        assertTrue(exceptionCaught);

        resource = classLoader.getResource("signed.jar");
        loader = new SignatureCheckingJarLoader(resource.getFile(), null);
        loader.setAcceptedCertificate(cert);
        loader.readJarFile();

        Class<?> cls = loader.loadClass("Example");
        assertNotNull(cls);
        Constructor<?> ctor = cls.getConstructors()[0];
        Object obj = ctor.newInstance();
        Method method = cls.getMethod("foo");
        long result = (Long) method.invoke(obj);
        assertEquals(0xDECAFL, result);
    }
}
