package org.lantern;

import static org.junit.Assert.assertTrue;

import java.io.File;
import java.net.Socket;

import org.apache.commons.lang.math.RandomUtils;
import org.jivesoftware.smack.proxy.ProxyInfo;
import org.jivesoftware.smack.proxy.ProxyInfo.ProxyType;
import org.junit.Test;
import org.littleshoot.proxy.KeyStoreManager;

public class ProxySocketFactoryTest {

    @Test
    public void test() throws Exception {
        System.setProperty("javax.net.debug", "ssl");
        final ProxyInfo info = new ProxyInfo(ProxyType.HTTP, 
            LanternClientConstants.FALLBACK_SERVER_HOST, 
            Integer.parseInt(LanternClientConstants.FALLBACK_SERVER_PORT), "", "");
        // Test creating a socket through our fallback proxy.
        final File temp = new File(String.valueOf(RandomUtils.nextInt()));
        temp.deleteOnExit();
        final KeyStoreManager ksm = new LanternKeyStoreManager(temp);
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        assertTrue(trustStore.TRUSTSTORE_FILE.isFile());
        
        final LanternSocketsUtil util = new LanternSocketsUtil(null, trustStore);
        final ProxySocketFactory factory = new ProxySocketFactory(util, info);
        
        // Just make sure we're able to establish the socket.
        final Socket sock = factory.createSocket("talk.google.com", 5222);
        assertTrue(sock.isConnected());
        sock.close();
        temp.delete();
    }

}
