package org.lantern.kscope;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;

import org.apache.commons.lang3.StringUtils;
import org.lantern.LanternClientConstants;

/**
 * Advertisement for a Lantern node to be distributed using the Kaleidoscope
 * limited advertisement protocol.
 */
public class LanternKscopeAdvertisement {

    public static final int CURRENT_VERSION = 1;
    public static final int DEFAULT_TTL = 1;

    private String jid;

    private int ttl;
    
    private String address;

    private int port;

    private int version;

    private String localAddress;
    
    private int localPort;

    private String lanternVersion = LanternClientConstants.VERSION;

    public static LanternKscopeAdvertisement makeRelayAd(
            final LanternKscopeAdvertisement ad) {
        return new LanternKscopeAdvertisement(ad.getJid(), ad.getAddress(),
            ad.getPort(), ad.getLocalAddress(), ad.getLocalPort());
    }

    public LanternKscopeAdvertisement(final String jid, 
        final InetSocketAddress local) {
        this(jid, "", 0, local.getAddress().getHostAddress(), local.getPort());
    }

    public LanternKscopeAdvertisement(final String jid, final InetAddress addr, 
        final int port, final InetSocketAddress localAddress) {
        this(jid, addr.getHostAddress(), port, 
            localAddress.getAddress().getHostAddress(), localAddress.getPort());
    }

    private LanternKscopeAdvertisement(final String jid, final String addr,
            final int port, final String localAddress, final int localPort) {
        this.jid = jid;
        this.address = addr;
        if (StringUtils.isBlank(localAddress)) {
            throw new IllegalArgumentException(
                "Should always have a local address!");
        }
        if (localPort < 1024) {
            throw new IllegalArgumentException(
                "Should always have a local port but was: "+localPort);
        }
        this.port = port;
        this.localAddress = localAddress;
        this.localPort = localPort;
        this.version = CURRENT_VERSION;
        this.ttl = DEFAULT_TTL;
    }

    public String getJid() {
        return jid;
    }

    public void setJid(String jid) {
        this.jid = jid;
    }

    public String getAddress() {
        return address;
    }

    public void setAddress(String addr) {
        this.address = addr;
    }

    public int getPort() {
        return port;
    }

    public void setPort(int port) {
        this.port = port;
    }

    public int getVersion() {
        return version;
    }

    public void setVersion(int version) {
        this.version = version;
    }

    public String getLocalAddress() {
        return localAddress;
    }

    public void setLocalAddress(String localAddress) {
        this.localAddress = localAddress;
    }

    public int getTtl() {
        return ttl;
    }

    public void setTtl(int ttl) {
        this.ttl = ttl;
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

    public int getLocalPort() {
        return localPort;
    }

    public void setLocalPort(int localPort) {
        this.localPort = localPort;
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
