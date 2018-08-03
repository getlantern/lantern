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
    public void test() throws Exception {
        log.debug("Running proxy socket factory test");
        Launcher.configureCipherSuites();
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
        
        assertTrue(sock.isConnected());
        sock.close();
    }

}
