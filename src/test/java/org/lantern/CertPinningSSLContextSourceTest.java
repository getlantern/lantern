package org.lantern;

import static org.junit.Assert.*;

import java.net.InetSocketAddress;

import javax.net.ssl.SSLSocket;

import org.junit.Test;
import org.lantern.loggly.Loggly;
import org.lantern.papertrail.Papertrail;
import org.lantern.papertrail.PapertrailAppender;

public class CertPinningSSLContextSourceTest {

    @Test
    public void testSuccessLoggly() throws Exception {
        CertPinningSSLContextSource source = new CertPinningSSLContextSource(
                "loggly", Loggly.LOGGLY_CERT);
        SSLSocket socket = (SSLSocket) source.getContext(null)
                .getSocketFactory()
                .createSocket();
        socket.connect(new InetSocketAddress(Loggly.LOGGLY_HOST, 443));
        socket.startHandshake();
    }

    @Test
    public void testSuccessPapertrail() throws Exception {
        CertPinningSSLContextSource source = new CertPinningSSLContextSource(
                "papertrail", Papertrail.PAPERTRAIL_CERT);
        SSLSocket socket = (SSLSocket) source.getContext(null)
                .getSocketFactory()
                .createSocket();
        socket.connect(new InetSocketAddress(
                PapertrailAppender.PAPERTRAIL_HOST,
                PapertrailAppender.PAPERTRAIL_PORT));
        socket.startHandshake();
    }

    @Test
    public void testFailure() throws Exception {
        CertPinningSSLContextSource source = new CertPinningSSLContextSource(
                "loggly", Loggly.LOGGLY_CERT);
        SSLSocket socket = (SSLSocket) source.getContext(null)
                .getSocketFactory()
                .createSocket();
        socket.connect(new InetSocketAddress("www.facebook.com", 443));
        try {
            socket.startHandshake();
            fail("Facebook shouldn't have been allowed with Google cert");
        } catch (Exception e) {
            // this is okay
        }
    }
}
