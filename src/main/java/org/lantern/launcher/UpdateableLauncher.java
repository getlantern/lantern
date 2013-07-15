package org.lantern.launcher;

/*
 * Includes code from @(#)MyJCE.java  to which the following notice
 * applies (typo of "reproduct" for "reproduce" in original):
 *
 * Copyright (c) 2002, Oracle and/or its affiliates. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 * -Redistributions of source code must retain the above copyright
 * notice, this  list of conditions and the following disclaimer.
 *
 * -Redistribution in binary form must reproduct the above copyright
 * notice, this list of conditions and the following disclaimer in
 * the documentation and/or other materials provided with the
 * distribution.
 *
 * Neither the name of Oracle or the names of
 * contributors may be used to endorse or promote products derived
 * from this software without specific prior written permission.
 *
 * This software is provided "AS IS," without a warranty of any
 * kind. ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND
 * WARRANTIES, INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE OR NON-INFRINGEMENT, ARE HEREBY
 * EXCLUDED. SUN AND ITS LICENSORS SHALL NOT BE LIABLE FOR ANY
 * DAMAGES OR LIABILITIES  SUFFERED BY LICENSEE AS A RESULT OF  OR
 * RELATING TO USE, MODIFICATION OR DISTRIBUTION OF THE SOFTWARE OR
 * ITS DERIVATIVES. IN NO EVENT WILL SUN OR ITS LICENSORS BE LIABLE
 * FOR ANY LOST REVENUE, PROFIT OR DATA, OR FOR DIRECT, INDIRECT,
 * SPECIAL, CONSEQUENTIAL, INCIDENTAL OR PUNITIVE DAMAGES, HOWEVER
 * CAUSED AND REGARDLESS OF THE THEORY OF LIABILITY, ARISING OUT OF
 * THE USE OF OR INABILITY TO USE SOFTWARE, EVEN IF SUN HAS BEEN
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
 *
 * You acknowledge that Software is not designed, licensed or
 * intended for use in the design, construction, operation or
 * maintenance of any nuclear facility.
 */

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Method;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLClassLoader;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.List;

import org.apache.log4j.lf5.util.StreamUtils;

/**
 * Lantern's JAR file is, sometimes, stored in a place where Lantern cannot
 * update it (say, because it's owned by root). But we would like to be able to
 * do updates. So, this launcher checks the user's .lantern directory for a
 * lantern JAR, and if it is there, it loads it and runs Launcher out of it. If
 * it's not there, it checks the Lantern install directory for a lantern JAR and
 * runs that. In each case, it checks the signatures against an included cert.
 *
 */
public class UpdateableLauncher {
    public static final String LANTERN_JAR_NAME = "lantern.jar";
    private final SignatureCheckingJarLoader loader;

    public UpdateableLauncher(String filename, X509Certificate cert)
            throws MalformedURLException, IOException {
        SignatureCheckingJarLoader loader = new SignatureCheckingJarLoader(
                filename, null);
        loader.setAcceptedCertificate(cert);
        loader.readJarFile();
        this.loader = loader;
    }

    public static X509Certificate loadCert() {
        String systemLantern = System.getProperty("user.dir");
        File file = new File(systemLantern, "lantern.cer");
        X509Certificate cert = SignatureCheckingJarLoader.loadCert(file);
        byte[] signature = cert.getSignature();
        // fixme: need to check that the signature (or pubkey, or something)
        // is actually the one we think it is.
        System.out.println("HERE:" + signature.length);
        return cert;
    }

    public static void main(String[] args) {

        UpdateableLauncher launcher = null;
        X509Certificate cert = loadCert();
        try {
            File dotLantern = new File(System.getProperty("user.home"),
                    ".lantern");
            File dotLanternJar = new File(dotLantern, LANTERN_JAR_NAME);
            launcher = new UpdateableLauncher(dotLanternJar.toString(), cert);
        } catch (Exception e) {
            try {
                String systemLantern = System.getProperty("user.dir");
                File systemLanternJar = new File(systemLantern,
                        LANTERN_JAR_NAME);
                launcher = new UpdateableLauncher(systemLanternJar.toString(),
                        cert);
            } catch (Exception e2) {
                throw new RuntimeException(e2);
            }
        }
        launcher.launch(args);
    }

    private void launch(String[] args) {
        try {

            Class<?> cls = loader.loadClass("org.lantern.Launcher");
            ClassLoader otherLoader = makeClassloaderFromManifest();
            // FIXME: having generate a classloader, how do I use it?
            
            // TODO: need to read Class-Path from manifest
            // load bcprov

            Method method = cls.getMethod("main", String[].class);
            method.invoke(null);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private ClassLoader makeClassloaderFromManifest() throws IOException {
        InputStream is = loader.getResourceAsStream("META-INF/MANIFEST.MF");
        String manifest = new String(StreamUtils.getBytes(is));

        File userDir = new File(System.getProperty("user.dir"));
        File dotLantern = new File(System.getProperty("user.home"), ".lantern");
        List<URL> urls = new ArrayList<URL>();
        for (String line : manifest.split("\n")) {
            if (line.startsWith("Class-Path: ")) {
                String classpath = line.substring(12);
                URL url;
                if (classpath.startsWith("./")) {
                    // FIXME: we need to check user.dir and user.home
                    // but user.dir is not secure, because the user
                    // controls it.
                    // so we need to store signatures for class-path jars.
                    // This is shitty, but not really a fixable problem.
                    // Ideally, we would do this during the Maven build.

                    String localPart = classpath.replaceFirst("\\./", "");
                    File file = new File(userDir, localPart);
                    if (file.exists()) {
                        url = new URL(file.toString());
                    } else {
                        file = new File(dotLantern, localPart);
                        if (!file.exists()) {
                            throw new RuntimeException("Could not find file " + classpath);
                        }
                        url = new URL(file.toString());
                    }
                } else {
                    url = new URL(classpath.toString());
                }
                urls.add(url);

            }
        }
        ClassLoader cl2 = new URLClassLoader(urls.toArray(new URL[urls.size()]));
        return cl2;
    }

}
