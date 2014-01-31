package org.lantern.kscope;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;

import org.apache.commons.lang3.StringUtils;
import org.lantern.LanternClientConstants;
import org.lantern.proxy.ProxyInfo;

/**
 * Advertisement for a Lantern node to be distributed using the Kaleidoscope
 * limited advertisement protocol.
 */
public class LanternKscopeAdvertisement {

    public static final int CURRENT_VERSION = 1;
    public static final int DEFAULT_TTL = 1;

    private String jid;
    private ProxyInfo proxyInfo = new ProxyInfo();
    private int ttl;
    private int version;
    private String lanternVersion = LanternClientConstants.VERSION;

    public static LanternKscopeAdvertisement makeRelayAd(
            final LanternKscopeAdvertisement ad) {
        LanternKscopeAdvertisement relayAd = new LanternKscopeAdvertisement(
            ad.getJid(), ad.getAddress(),
            ad.getPort(), ad.getLocalAddress(),
            ad.getLocalPort(), true
        );
        relayAd.setTtl(ad.getTtl()-1);
        return relayAd;
    }

    /**
     * No arg constructor only used to build ads from JSON over the wire.
     */
    public LanternKscopeAdvertisement() {
        this("", "", 0, "", 0, false);
    }
    
    public LanternKscopeAdvertisement(final String jid, 
        final InetAddress publicAddress, final InetSocketAddress local) {
        this(jid, publicAddress.getHostAddress(), 0, 
                local.getAddress().getHostAddress(), local.getPort(), true);
    }

    public LanternKscopeAdvertisement(final String jid, final InetAddress addr, 
        final int port, final InetSocketAddress localAddress) {
        this(jid, addr.getHostAddress(), port, 
            localAddress.getAddress().getHostAddress(), localAddress.getPort(),
            true);
    }

    private LanternKscopeAdvertisement(final String jid, final String addr,
            final int port, final String localAddress, final int localPort,
            final boolean requireLocal) {
        this.jid = jid;
        this.setAddress(addr);
        if (StringUtils.isBlank(localAddress) && requireLocal) {
            throw new IllegalArgumentException(
                "Should always have a local address!");
        }
        if (localPort < 1024 && requireLocal) {
            throw new IllegalArgumentException(
                "Should always have a local port but was: "+localPort);
        }
        this.setPort(port);
        this.setLocalAddress(localAddress);
        this.setLocalPort(localPort);
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
        return proxyInfo.getAddress();
    }

    public void setAddress(String addr) {
        proxyInfo.setAddress(addr);
    }

    public int getPort() {
        return proxyInfo.getPort();
    }

    public void setPort(int port) {
        proxyInfo.setPort(port);
    }

    public int getVersion() {
        return version;
    }

    public void setVersion(int version) {
        this.version = version;
    }

    public String getLocalAddress() {
        return proxyInfo.getLocalAddress();
    }

    public void setLocalAddress(String localAddress) {
        proxyInfo.setLocalAddress(localAddress);
    }

    public int getTtl() {
        return ttl;
    }

    public void setTtl(int ttl) {
        this.ttl = ttl;
    }

    public boolean hasMappedEndpoint() {
        try {
            InetAddress.getAllByName(getAddress());
            return getPort() > 1;
        } catch (final UnknownHostException e) {
            return false;
        }
    }

    public String getLanternVersion() {
        return lanternVersion;
    }

    public int getLocalPort() {
        return proxyInfo.getLocalPort();
    }

    public void setLocalPort(int localPort) {
        proxyInfo.setLocalPort(localPort);
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result + ((getAddress() == null) ? 0 : getAddress().hashCode());
        result = prime * result + ((jid == null) ? 0 : jid.hashCode());
        result = prime * result
                + ((getLocalAddress() == null) ? 0 : getLocalAddress().hashCode());
        result = prime * result + getPort();
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
        if (getAddress() == null) {
            if (other.getAddress() != null)
                return false;
        } else if (!getAddress().equals(other.getAddress()))
            return false;
        if (jid == null) {
            if (other.jid != null)
                return false;
        } else if (!jid.equals(other.jid))
            return false;
        if (getLocalAddress() == null) {
            if (other.getLocalAddress() != null)
                return false;
        } else if (!getLocalAddress().equals(other.getLocalAddress()))
            return false;
        if (getPort() != other.getPort())
            return false;
        if (ttl != other.ttl)
            return false;
        if (version != other.version)
            return false;
        return true;
    }

    @Override
    public String toString() {
        return "LanternKscopeAdvertisement [jid=" + jid + ", ttl=" + ttl
                + ", address=" + getAddress() + ", port=" + getPort() + ", version="
                + version + ", localAddress=" + getLocalAddress() + ", localPort="
                + getLocalPort() + ", lanternVersion=" + lanternVersion + "]";
    }
    
}
