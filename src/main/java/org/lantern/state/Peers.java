package org.lantern.state;

import java.net.URI;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import com.google.common.collect.ImmutableMap;

public class Peers {

    private Map<URI, Peer> peers = new ConcurrentHashMap<URI, Peer>();
    
    public Peers() {
        
    }

    /*
    public void addPeer(final InetAddress isa, final Peer peer) {
        this.peers.put(isa.toString(), peer);
    }
    */
    
    public void addPeer(final URI jid, final Peer peer) {
        this.peers.put(jid, peer);
    }

    public Map<URI, Peer> getPeers() {
        synchronized(this.peers) {
            return ImmutableMap.copyOf(this.peers);
        }
    }
    
    public void setPeers(final Map<URI, Peer> peers) {
        this.peers = peers;
    }

    public void reset() {
        synchronized(this.peers) {
            for (final Peer peer : this.peers.values()) {
                peer.setOnline(false);
            }
        }
    }

    /*
    public Peer getPeer(final InetAddress isa) {
        return this.peers.get(isa.toString());
    }

    public boolean hasPeer(final InetAddress isa) {
        return this.peers.containsKey(isa.toString());
    }
    */
    
    public Peer getPeer(final URI userId) {
        return this.peers.get(userId.toASCIIString());
    }
    
    public boolean hasPeer(final URI userId) {
        return this.peers.containsKey(userId.toASCIIString());
    }
}
