package org.lantern.state;

import java.util.Collection;
import java.util.HashSet;
import java.util.Locale;

import org.apache.commons.lang3.StringUtils;
import org.lantern.PeerSocketWrapper;

import com.google.common.base.Preconditions;
import com.google.common.collect.ImmutableSet;

/**
 * Class containing data for an individual peer, including active connections,
 * IP address, etc.
 */
public class Peer {

    private final String userId;

    private final String country;
    
    private final boolean incoming;

    private final boolean natPmp;
    
    private final boolean upnp;
    
    private int connectionAttempts = 0;
    
    private final Collection<PeerSocketWrapper> sockets = 
        new HashSet<PeerSocketWrapper>();

    private final String base64Cert;

    public Peer(final String userId,
        final String base64Cert, final String countryCode, 
        final boolean incoming, 
        final boolean natPmp, final boolean upnp) {
        Preconditions.checkArgument(StringUtils.isNotBlank(base64Cert), 
                "No cert?");
        this.userId = userId;
        this.base64Cert = base64Cert;
        this.country = countryCode.toLowerCase(Locale.US);
        this.incoming = incoming;
        this.natPmp = natPmp;
        this.upnp = upnp;
    }

    public String getUserId() {
        return userId;
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

    public int getConnectionAttempts() {
        return connectionAttempts;
    }

    public void incrementConnectionAttempts() {
        this.connectionAttempts++;
    }

    public String getBase64Cert() {
        return base64Cert;
    }
}
