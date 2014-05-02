package org.lantern;

import java.net.InetSocketAddress;

import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

/**
 * This test fails with an SSL errorr - unable to find valid certification path
 * to requested target.
 */
public class CertChainTest {
    public static void main(final String... args) throws Exception {
        final SSLSocket sock = (SSLSocket) SSLSocketFactory.getDefault()
                .createSocket();
        sock.connect(new InetSocketAddress("img.truecar.com", 443), 10000);
        sock.getOutputStream().write(
                "GET /colorid_images/v1/979120/175x90/f3q".getBytes());
        sock.close();
    }
}
