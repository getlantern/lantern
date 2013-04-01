package org.lantern;

import java.net.InetSocketAddress;
import java.net.URI;

import org.lantern.state.Peer;
import org.lantern.state.Peer.Type;
import org.lantern.util.LanternTrafficCounter;

public interface PeerFactory {
    /**
     * This is called when we successfully make an outgoing connection to a 
     * peer.
     * 
     * @param fullJid The JID of the peer.
     * @param isa The remote address of the peer.
     * @param type The type of the peer.
     * @param trafficCounter The class for keeping track of traffic with the
     * peer.
     */
    void onOutgoingConnection(URI fullJid, InetSocketAddress isa, Type type, 
            LanternTrafficCounter trafficCounter);

    Peer addPeer(URI fullJid, Type type);
}
