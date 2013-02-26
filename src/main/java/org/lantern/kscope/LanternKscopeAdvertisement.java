package org.lantern.kscope;

import java.net.InetAddress;
import java.net.UnknownHostException;

import org.kaleidoscope.TrustGraphNode;

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
}
