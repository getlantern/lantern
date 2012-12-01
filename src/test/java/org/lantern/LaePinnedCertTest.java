package org.lantern;

import static org.junit.Assert.assertTrue;

import java.net.InetSocketAddress;
import java.util.concurrent.atomic.AtomicBoolean;

import javax.net.ssl.HandshakeCompletedEvent;
import javax.net.ssl.HandshakeCompletedListener;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

import org.junit.BeforeClass;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Guice;
import com.google.inject.Injector;


public class LaePinnedCertTest {

    private static Logger LOG = LoggerFactory.getLogger(LaePinnedCertTest.class);

    private static DefaultXmppHandler xmppHandler;

    private static LanternSocketsUtil socketsUtil;
    
    @BeforeClass
    public static void setup() throws Exception {
        final Injector injector = Guice.createInjector(new LanternModule());
        
        xmppHandler = injector.getInstance(DefaultXmppHandler.class);
        socketsUtil = injector.getInstance(LanternSocketsUtil.class);
        
        xmppHandler.start();
    }
    
    @Test public void testPinnedCert() throws Exception {
        //System.setProperty("javax.net.debug", "all");
        //LanternHub.getKeyStoreManager();
        final SSLSocketFactory tls = socketsUtil.newTlsSocketFactory();
        final SSLSocket sock = (SSLSocket) tls.createSocket();
        
        final AtomicBoolean completed = new AtomicBoolean(false);
        
        sock.addHandshakeCompletedListener(new HandshakeCompletedListener() {
            
            @Override
            public void handshakeCompleted(HandshakeCompletedEvent event) {
                completed.set(true);
            }
        });
        
        sock.connect(new InetSocketAddress("laeproxyhr1.appspot.com", 443), 10000);
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
    }
}
