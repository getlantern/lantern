package org.lantern;

import static org.junit.Assert.*;

import java.net.URI;

import org.junit.Test;
import org.lantern.DefaultPeerProxyManager.ConnectionTimeSocket;


public class DefaultPeerProxyManagerTest {

    @Test public void testQueue() throws Exception {
        final DefaultPeerProxyManager l = new DefaultPeerProxyManager(true);
        
        final URI peerUri = new URI("http://test.com");
        final ConnectionTimeSocket cts1 = l.new ConnectionTimeSocket(peerUri);
        cts1.elapsed = 1000L;
        final ConnectionTimeSocket cts2 = l.new ConnectionTimeSocket(peerUri);
        cts2.elapsed = 2000L;
        final ConnectionTimeSocket cts3 = l.new ConnectionTimeSocket(peerUri);
        cts3.elapsed = 3000L;
        final ConnectionTimeSocket cts4 = l.new ConnectionTimeSocket(peerUri);
        cts4.elapsed = 4000L;
        
        l.timedSockets.add(cts1);
        l.timedSockets.add(cts2);
        l.timedSockets.add(cts3);
        l.timedSockets.add(cts4);
        
        assertEquals(l.timedSockets.poll(), cts1);
        assertEquals(l.timedSockets.poll(), cts2);
        assertEquals(l.timedSockets.poll(), cts3);
        assertEquals(l.timedSockets.poll(), cts4);
    }
}
