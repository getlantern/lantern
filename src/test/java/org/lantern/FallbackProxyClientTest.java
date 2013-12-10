package org.lantern;

import static org.junit.Assert.*;

import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;

import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

import org.junit.Test;

public class FallbackProxyClientTest {

    @Test
    public void testFallbackRawSocket() throws Exception {
        //System.setProperty("javax.net.debug", "ssl");
        final LanternKeyStoreManager ksm = TestingUtils.newKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        final LanternSocketsUtil socketsUtil =
            new LanternSocketsUtil(null, trustStore);

        Launcher.configureCipherSuites();
        //trustStore.listEntries();
        final SSLSocketFactory socketFactory = socketsUtil.newTlsSocketFactoryJavaCipherSuites();
        
        final SSLSocket sock = (SSLSocket) socketFactory.createSocket();
        sock.connect(new InetSocketAddress("54.254.96.14", 16589), 20000);
        assertTrue(sock.isConnected());
        
        final OutputStream os = sock.getOutputStream();
        os.write("GET http://www.google.com HTTP/1.1\r\nHost: www.google.com\r\n\r\n".getBytes());
        os.flush();
        
        final InputStream is = sock.getInputStream();
        final byte[] bytes = new byte[30];
        is.read(bytes);
        
        final String response = new String(bytes);
        assertTrue(response.startsWith("HTTP/1.1 302 Found"));
        System.out.println(new String(bytes));
        os.close();
        is.close();
    }

}
