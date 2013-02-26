package org.lantern.kscope;

import java.net.InetAddress;
import java.net.UnknownHostException;

import org.kaleidoscope.TrustGraphNode;
import org.lantern.LanternConstants;

/**
 * Advertisement for a Lantern node to be distributed using the Kaleidoscope
 * limited advertisement protocol.
 */
public class LanternKscopeAdvertisement {

    public static final int CURRENT_VERSION = 1;
    public static final int DEFAULT_TTL = 1;

    private final String jid;

    private final int ttl;
    
    private final String address;

    private final int port;

    private final int version;

    private final String localAddress;

    private final String lanternVersion = LanternConstants.VERSION;

    public static LanternKscopeAdvertisement makeRelayAd(
            LanternKscopeAdvertisement ad) {
        return new LanternKscopeAdvertisement(ad.getJid(), ad.getAddress(),
            ad.getPort(), ad.getLocalAddress());
    }

    public LanternKscopeAdvertisement(final String jid) {
        this(jid, "", 0);
    }

    public LanternKscopeAdvertisement(final String jid, final InetAddress addr, 
        final int port) {
        this(jid, addr.getHostAddress(), port);
    }
    
    public LanternKscopeAdvertisement(final String jid, final String addr, 
        final int port) {
        this(jid, addr, port, "");
    }

    public LanternKscopeAdvertisement(final String jid, final String addr,
            final int port, final String localAddress) {
        this.jid = jid;
        this.address = addr;
        this.port = port;
        this.localAddress = localAddress;
        this.version = CURRENT_VERSION;
        this.ttl = DEFAULT_TTL;
    }

    public String getJid() {
        return jid;
    }

    public String getAddress() {
        return address;
    }

    public int getPort() {
        return port;
    }

    public int getVersion() {
        return version;
    }

    public String getLocalAddress() {
        return localAddress;
    }

    public int getTtl() {
        return ttl;
    }

    public boolean hasMappedEndpoint() {
        try {
            InetAddress.getAllByName(address);
            return this.port > 1;
        } catch (final UnknownHostException e) {
            return false;
        }
    }

    public String getLanternVersion() {
        return lanternVersion;
    }
    
    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result + ((address == null) ? 0 : address.hashCode());
        result = prime * result + ((jid == null) ? 0 : jid.hashCode());
        result = prime * result
                + ((localAddress == null) ? 0 : localAddress.hashCode());
        result = prime * result + port;
        result = prime * result + ttl;
        result = prime * result + version;
        return result;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj)
            return true;
        if (obj == null)
            return false;
        if (getClass() != obj.getClass())
            return false;
        LanternKscopeAdvertisement other = (LanternKscopeAdvertisement) obj;
        if (address == null) {
            if (other.address != null)
                return false;
        } else if (!address.equals(other.address))
            return false;
        if (jid == null) {
            if (other.jid != null)
                return false;
        } else if (!jid.equals(other.jid))
            return false;
        if (localAddress == null) {
            if (other.localAddress != null)
                return false;
        } else if (!localAddress.equals(other.localAddress))
            return false;
        if (port != other.port)
            return false;
        if (ttl != other.ttl)
            return false;
        if (version != other.version)
            return false;
        return true;
    }
}
