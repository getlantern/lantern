package org.lantern;

import static org.junit.Assert.*;

import java.net.Socket;
import java.util.concurrent.Callable;

import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ProxySocketFactoryTest {

    private final Logger log = LoggerFactory.getLogger(getClass());

    @Test
    public void testSuccess() throws Exception {
        log.debug("Running proxy socket factory testSuccess");
        Socket sock = doTest();
        assertTrue(sock.isConnected());
        sock.close();
    }

    @Test
    public void testTimeout() throws Exception {
        log.debug("Running proxy socket factory testFailure");
        int originalConnectTimeout = ProxySocketFactory.CONNECT_TIMEOUT;
        try {
            // Temporarily mess with the FIVE_SECONDS variable to make sure
            // timing out works
            ProxySocketFactory.CONNECT_TIMEOUT = 1;
            doTest();
            fail("CONNECT should have timed out");
        } catch (Exception e) {
            // This is good
        } finally {
            ProxySocketFactory.CONNECT_TIMEOUT = originalConnectTimeout;
        }
    }

    private Socket doTest() throws Exception {
        System.setProperty("javax.net.debug", "ssl");

        Socket sock = TestingUtils.doWithGetModeProxy(new Callable<Socket>() {
            @Override
            public Socket call() throws Exception {
                // Test creating a socket through our fallback proxy.
                final ProxySocketFactory factory = new ProxySocketFactory();

                // Just make sure we're able to establish the socket.
                return factory.createSocket("talk.google.com", 5222);
            }
        });

        return sock;
    }
}
