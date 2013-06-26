package org.lantern;

import static org.junit.Assert.assertTrue;

import java.net.Socket;

import org.jivesoftware.smack.proxy.ProxyInfo;
import org.jivesoftware.smack.proxy.ProxyInfo.ProxyType;
import org.junit.Test;
import org.littleshoot.proxy.KeyStoreManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ProxySocketFactoryTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Test
    public void test() throws Exception {
        log.debug("Running proxy socket factory test");
        //System.setProperty("javax.net.debug", "ssl");
        
        // Change the server to use because the default LittleProxy server
        // doesn't support higher bit length encryption. That will cause this
        // test to fail if another test configures high bit rated encryption.
        final ProxyInfo info = new ProxyInfo(ProxyType.HTTP, 
                "54.254.96.14", 16589, "", "");
            //LanternClientConstants.FALLBACK_SERVER_HOST, 
            //Integer.parseInt(LanternClientConstants.FALLBACK_SERVER_PORT), "", "");
        // Test creating a socket through our fallback proxy.
        final KeyStoreManager ksm = TestingUtils.newKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        assertTrue(trustStore.TRUSTSTORE_FILE.isFile());
        
        final LanternSocketsUtil util = new LanternSocketsUtil(null, trustStore);
        final ProxyTracker tracker = TestingUtils.newProxyTracker();
        final ProxySocketFactory factory = new ProxySocketFactory(util, tracker);
        
        // Just make sure we're able to establish the socket.
        final Socket sock = factory.createSocket("talk.google.com", 5222);
        assertTrue(sock.isConnected());
        sock.close();
    }

}
