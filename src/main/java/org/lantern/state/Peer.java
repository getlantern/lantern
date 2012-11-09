package org.lantern.state;

import java.util.Collection;
import java.util.HashSet;

import org.lantern.PeerSocketWrapper;

import com.google.common.collect.ImmutableSet;

/**
 * Class containing data for an individual peer, including active connections,
 * IP address, etc.
 */
public class Peer {

    private final String userId;

    private final String ip;
    
    private final String country;
    
    private final Collection<PeerSocketWrapper> sockets = 
        new HashSet<PeerSocketWrapper>();
    
    public Peer(final String userId, final String ip, final String country) {
        this.userId = userId;
        this.ip = ip;
        this.country = country;
    }

    
    public String getUserId() {
        return userId;
    }

    public String getIp() {
        return ip;
    }

    public String getCountry() {
        return country;
    }

    public Collection<PeerSocketWrapper> getSockets() {
        synchronized (sockets) {
            return ImmutableSet.copyOf(sockets);
        }
    }

    public void removeSocket(final PeerSocketWrapper cts) {
        synchronized (sockets) {
            this.sockets.remove(cts);
        }
    }

    public void addSocket(final PeerSocketWrapper cts) {
        synchronized (sockets) {
            this.sockets.add(cts);
        }
    }
}
