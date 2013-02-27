package org.lantern.state;

import java.net.InetSocketAddress;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import com.google.common.collect.ImmutableMap;

public class Peers {

    private Map<String, Peer> peers = new ConcurrentHashMap<String, Peer>();
    
    public Peers() {
        
    }

    public void addPeer(final InetSocketAddress isa, final Peer peer) {
        this.peers.put(isa.toString(), peer);
    }
    
    public void addPeer(final String jid, final Peer peer) {
        this.peers.put(jid, peer);
    }

    public Map<String, Peer> getPeers() {
        synchronized(this.peers) {
            return ImmutableMap.copyOf(this.peers);
        }
    }
    
    public void setPeers(final Map<String, Peer> peers) {
        this.peers = peers;
    }

    public void reset() {
        synchronized(this.peers) {
            for (final Peer peer : this.peers.values()) {
                peer.setOnline(false);
            }
        }
    }

    public Peer getPeer(final InetSocketAddress isa) {
        return this.peers.get(isa.toString());
    }

    public Peer getPeer(final String userId) {
        return this.peers.get(userId);
    }
    
    public boolean hasPeer(final String userId) {
        return this.peers.containsKey(userId);
    }

    public boolean hasPeer(final InetSocketAddress isa) {
        return this.peers.containsKey(isa.toString());
    }

}
