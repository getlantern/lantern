package org.lantern;

import java.util.Collection;
import java.util.HashSet;

import org.lantern.DefaultPeerProxyManager.ConnectionTimeSocket;

import com.google.common.collect.ImmutableSet;

/**
 * Class containing data for an individual peer, including active connections,
 * IP address, etc.
 */
public class Peer {

    private final String userId;

    private final String ip;
    
    private final String country;
    
    private final Collection<ConnectionTimeSocket> sockets = 
        new HashSet<ConnectionTimeSocket>();
    
    public Peer(final String userId, final ConnectionTimeSocket sock, 
        final String country) {
        this.userId = userId;
        this.ip = sock.getSocket().getInetAddress().getHostAddress();
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

    public Collection<ConnectionTimeSocket> getSockets() {
        synchronized (sockets) {
            return ImmutableSet.copyOf(sockets);
        }
    }

    public void removeSocket(final ConnectionTimeSocket cts) {
        synchronized (sockets) {
            this.sockets.remove(cts);
        }
    }


    public void addSocket(final ConnectionTimeSocket cts) {
        synchronized (sockets) {
            this.sockets.add(cts);
        }
    }
}
