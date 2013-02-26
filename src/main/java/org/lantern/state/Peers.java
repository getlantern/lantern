package org.lantern.state;

import java.util.Collection;
import java.util.HashSet;

import com.google.common.collect.ImmutableSet;

public class Peers {

    private Collection<Peer> peers = new HashSet<Peer>();
    
    public Peers() {
        
    }

    public void addPeer(final Peer peer) {
        this.peers.add(peer);
    }

    public Collection<Peer> getPeers() {
        synchronized(this.peers) {
            return ImmutableSet.copyOf(peers);
        }
    }

    public void reset() {
        synchronized(this.peers) {
            for (final Peer peer : this.peers) {
                peer.setOnline(false);
                peer.setConnected(false);
            }
        }
    }

}
