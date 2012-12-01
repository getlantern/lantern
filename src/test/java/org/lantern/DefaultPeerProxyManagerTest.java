package org.lantern;

import static org.junit.Assert.assertEquals;

import java.net.Socket;
import java.net.URI;

import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.group.DefaultChannelGroup;
import org.junit.BeforeClass;
import org.junit.Test;

import com.google.inject.Guice;
import com.google.inject.Injector;


public class DefaultPeerProxyManagerTest {

    private static AnonymousPeerProxyManager anon;
    private static Stats stats;
    private static LanternSocketsUtil sockets;
    
    @BeforeClass
    public static void setup() throws Exception {
        final Injector injector = Guice.createInjector(new LanternModule());
        
        // Order annoyingly matters -- have to create xmpp handler first.
        injector.getInstance(DefaultXmppHandler.class);
        anon = injector.getInstance(AnonymousPeerProxyManager.class);
        stats = injector.getInstance(Stats.class);
        sockets = injector.getInstance(LanternSocketsUtil.class);
    }
    
    
    @Test public void testQueue() throws Exception {
        final ChannelGroup channelGroup = 
            new DefaultChannelGroup("Local-HTTP-Proxy-Server");
        
        final URI peerUri = new URI("http://test.com");
        final long time1 = 0;
        final long time2 = 1;
        final long time3 = 2;
        final long time4 = 3;
        

        final PeerSocketWrapper cts1 = 
            new PeerSocketWrapper(peerUri, time4, new Socket(), true, channelGroup, stats, sockets);
        final PeerSocketWrapper cts2 = 
            new PeerSocketWrapper(peerUri, time3, new Socket(), true, channelGroup, stats, sockets);
        final PeerSocketWrapper cts3 = 
            new PeerSocketWrapper(peerUri, time2, new Socket(), true, channelGroup, stats, sockets);
        final PeerSocketWrapper cts4 = 
            new PeerSocketWrapper(peerUri, time1, new Socket(), true, channelGroup, stats, sockets);
        
        anon.timedSockets.add(cts1);
        anon.timedSockets.add(cts2);
        anon.timedSockets.add(cts3);
        anon.timedSockets.add(cts4);
        
        assertEquals(anon.timedSockets.poll(), cts1);
        assertEquals(anon.timedSockets.poll(), cts2);
        assertEquals(anon.timedSockets.poll(), cts3);
        assertEquals(anon.timedSockets.poll(), cts4);
    }
}
