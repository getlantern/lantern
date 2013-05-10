package org.lantern;

import static org.junit.Assert.assertTrue;

import java.io.File;
import java.net.InetSocketAddress;
import java.util.concurrent.atomic.AtomicBoolean;

import javax.net.ssl.HandshakeCompletedEvent;
import javax.net.ssl.HandshakeCompletedListener;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

import org.apache.commons.lang.math.RandomUtils;
import org.junit.Test;
import org.littleshoot.proxy.KeyStoreManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LaePinnedCertTest {

    private static Logger LOG = 
        LoggerFactory.getLogger(LaePinnedCertTest.class);
    
    @Test public void testPinnedCert() throws Exception {
        final File temp = new File(String.valueOf(RandomUtils.nextInt()));
        temp.deleteOnExit();
        final KeyStoreManager ksm = new LanternKeyStoreManager(temp);
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        
        System.setProperty("javax.net.ssl.trustStore",
                trustStore.TRUSTSTORE_FILE.getAbsolutePath());
        
        final LanternSocketsUtil socketsUtil = 
            new LanternSocketsUtil(null, trustStore);
        
        final SSLSocketFactory tls = socketsUtil.newTlsSocketFactory();
        final SSLSocket sock = (SSLSocket) tls.createSocket();
        
        final AtomicBoolean completed = new AtomicBoolean(false);
        
        sock.addHandshakeCompletedListener(new HandshakeCompletedListener() {
            
            @Override
            public void handshakeCompleted(HandshakeCompletedEvent event) {
                completed.set(true);
            }
        });
        
        sock.connect(new InetSocketAddress("laeproxyhr1.appspot.com", 443), 
            10000);
        assertTrue(sock.isConnected());
        
        sock.startHandshake();
        int i = 0;
        while (i < 20) {
            if (!completed.get()) {
                Thread.sleep(100);
            } else {
                break;
            }
            i++;
        }
        assertTrue("Handshake not completed!!", completed.get());
        temp.delete();
    }
}
