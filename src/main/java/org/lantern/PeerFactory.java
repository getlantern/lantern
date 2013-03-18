package org.lantern;

import java.net.InetAddress;
import java.net.InetSocketAddress;

import org.lantern.state.Peer.Type;
import org.lantern.util.LanternTrafficCounter;

public interface PeerFactory {

    /**
     * Adds an incoming peer. Note that this method purely uses the address
     * of the incoming peer and not the JID. For the case of port-mapped peers,
     * this will be accurate because the remote address is in fact the address
     * of the peer. For p2p connections, however, there's an intermediary 
     * step where we typically copy data from a temporary local server to the 
     * local HTTP server, for the purposes of making ICE work more simply 
     * (i.e. that way the HTTP server doesn't have to worry about ICE but 
     * rather just about servicing incoming sockets). The problem is that if 
     * this method is used to add those peers, their IP address will always 
     * be the IP address of localhost, so they will not be mapped correctly. 
     * Their data will be tracked correctly, however. 
     * 
     * See:
     * 
     * https://github.com/adamfisk/littleshoot-util/blob/master/src/main/java/org/littleshoot/util/RelayingSocketHandler.java
     * 
     * @param address The address of the peer.
     * @param trafficCounter The counter for keeping track of traffic to and
     * from the peer.
     */
    void addIncomingPeer(InetAddress address, 
        LanternTrafficCounter trafficCounter);
    
    void addOutgoingPeer(String fullJid, InetSocketAddress isa, Type type, 
            LanternTrafficCounter trafficCounter);
}
