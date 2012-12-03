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

    private final int port;
    
    private final String country;
    
    private final boolean incoming;

    private final boolean natPmp;
    
    private final boolean upnp;
    
    private final Collection<PeerSocketWrapper> sockets = 
        new HashSet<PeerSocketWrapper>();

    public Peer(final String userId, final String ip, final int port,
        final String country,final boolean incoming, 
        final boolean natPmp, final boolean upnp) {
        this.userId = userId;
        this.ip = ip;
        this.port = port;
        this.country = country;
        this.incoming = incoming;
        this.natPmp = natPmp;
        this.upnp = upnp;
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


    public boolean isIncoming() {
        return incoming;
    }


    public boolean isNatPmp() {
        return natPmp;
    }


    public boolean isUpnp() {
        return upnp;
    }


    public int getPort() {
        return port;
    }
}
