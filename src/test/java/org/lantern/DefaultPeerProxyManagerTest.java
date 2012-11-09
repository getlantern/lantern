package org.lantern;

import static org.junit.Assert.assertEquals;

import java.net.Socket;
import java.net.URI;

import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.group.DefaultChannelGroup;
import org.junit.Test;


public class DefaultPeerProxyManagerTest {

    @Test public void testQueue() throws Exception {

        final ChannelGroup channelGroup = 
            new DefaultChannelGroup("Local-HTTP-Proxy-Server");
        
        final DefaultPeerProxyManager l = 
            new DefaultPeerProxyManager(true, channelGroup);
        
        final URI peerUri = new URI("http://test.com");
        final long time1 = 0;
        final long time2 = 1;
        final long time3 = 2;
        final long time4 = 3;
        final PeerSocketWrapper cts1 = 
            new PeerSocketWrapper(peerUri, time4, new Socket(), true, channelGroup);
        final PeerSocketWrapper cts2 = 
            new PeerSocketWrapper(peerUri, time3, new Socket(), true, channelGroup);
        final PeerSocketWrapper cts3 = 
            new PeerSocketWrapper(peerUri, time2, new Socket(), true, channelGroup);
        final PeerSocketWrapper cts4 = 
            new PeerSocketWrapper(peerUri, time1, new Socket(), true, channelGroup);
        
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
