package org.lantern;

import java.net.InetSocketAddress;

import javax.net.ssl.SSLSocket;

/**
 * This test fails with an SSL error - unable to find valid certification path
 * to requested target.  That is because TrueCar's web server is not returning
 * intermediate CA certificates.
 */
public class CertChainTest {
    public static void main(final String... args) throws Exception {
        LanternTrustStore ts = new LanternTrustStore(new LanternKeyStoreManager());
        final SSLSocket sock = (SSLSocket) ts.getCumulativeSslContext().getSocketFactory()
                .createSocket();
        sock.connect(new InetSocketAddress("img.truecar.com", 443), 10000);
        sock.getOutputStream().write(
                "GET /colorid_images/v1/979120/175x90/f3q".getBytes());
        sock.close();
    }
}
