package org.lantern;

import java.io.OutputStream;
import java.net.Socket;
import java.net.URI;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.commons.lang.StringUtils;
import org.junit.BeforeClass;
import org.junit.Test;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Guice;
import com.google.inject.Injector;


public class PeerSocketTest {
    
    private final Logger log = LoggerFactory.getLogger(getClass());

    private static DefaultXmppHandler xmpp;
    
    @BeforeClass
    public static void setup() throws Exception {
        final Injector injector = Guice.createInjector(new LanternModule());
        xmpp = injector.getInstance(DefaultXmppHandler.class);
        xmpp.start();
    }
    @Test
    public void testSocket() throws Exception {
        // Note you have to have a remote peer URI that's up a running for
        // this test to work. In the future we'll likely develop a test
        // framework that simulates things like unpredictable network latency
        // and doesn't require live tests over the network.
        
        final String email = TestUtils.loadTestEmail();
        final String pass = TestUtils.loadTestPassword();
        
        if (StringUtils.isBlank(email) || StringUtils.isBlank(pass)) {
            log.info("user name and password not configured");
            return;
        }
        xmpp.connect(email, pass);

        // ENTER A PEER TO RUN LIVE TESTS -- THEY NEED TO BE ON THE NETWORK.
        final String peer = "";
        if (StringUtils.isBlank(peer)) {
            return;
        }
        final URI uri = new URI(peer);
        IceConfig.setTcp(false);

        final Collection<Socket> socks = new ArrayList<Socket>();
        for (int i = 0; i < 40; i++) {
            final long start = System.currentTimeMillis();
            try {
                final Socket s = LanternUtils.openOutgoingPeerSocket(uri, 
                        xmpp.getP2PClient(), 
                    new HashMap<URI, AtomicInteger>());
                final long elapsed = System.currentTimeMillis() - start;
                log.info("Elapsed: "+elapsed);
                final byte[] data = new byte[2000];
                Arrays.fill(data, Byte.MAX_VALUE);
                final OutputStream os = s.getOutputStream();
                os.write(data);
                os.flush();
            } catch (final Exception e) {
                log.error("Error connecting on pass "+i);
                throw e;
            }
        }
        Thread.sleep(10000);
        for (final Socket sock : socks) {
            sock.close();
        }
    }
}
