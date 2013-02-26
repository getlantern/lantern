package org.lantern.kscope;

import java.net.InetAddress;
import java.net.UnknownHostException;

/**
 * Advertisement for a Lantern node to be distributed using the Kaleidoscope
 * limited advertisement protocol.
 */
public class LanternKscopeAdvertisement {

    private final String jid;
    
    private final String address;
    
    private final int port;
    
    public LanternKscopeAdvertisement(final String jid) {
        this(jid, "", 0);
    }

    public LanternKscopeAdvertisement(final String jid, final InetAddress addr, 
        final int port) {
        this(jid, addr.getHostAddress(), port);
    }
    
    public LanternKscopeAdvertisement(final String jid, final String addr, 
        final int port) {
        this.jid = jid;
        this.address = addr;
        this.port = port;
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
    
    public boolean hasMappedEndpoint() {
        try {
            InetAddress.getAllByName(address);
            return this.port > 1;
        } catch (final UnknownHostException e) {
            return false;
        }
    }
}
