package org.lantern;

import static org.junit.Assert.*;

import java.net.URI;

import org.junit.Test;
import org.lantern.DefaultPeerProxyManager.ConnectionTimeSocket;


public class DefaultPeerProxyManagerTest {

    @Test public void testQueue() throws Exception {
        final DefaultPeerProxyManager l =
            new DefaultPeerProxyManager(true);
        
        final URI peerUri = new URI("http://test.com");
        final ConnectionTimeSocket cts1 = l.new ConnectionTimeSocket(peerUri);
        cts1.elapsed = 1000L;
        final ConnectionTimeSocket cts2 = l.new ConnectionTimeSocket(peerUri);
        cts2.elapsed = 2000L;
        l.timedSockets.add(cts1);
        l.timedSockets.add(cts2);
        
        final ConnectionTimeSocket cts = l.timedSockets.poll();
        assertEquals(cts, cts1);
    }
}
