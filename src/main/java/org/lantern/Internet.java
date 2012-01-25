package org.lantern;

import java.net.InetAddress;
import java.net.SocketException;
import java.net.UnknownHostException;

import org.lastbamboo.common.stun.client.PublicIpAddress;
import org.littleshoot.util.NetworkUtils;

/**
 * Stores data about the user's internet connection.
 */
public class Internet {

    private String privateAddress;
    private String publicAddress;
    
    public Internet() {
        try {
            this.privateAddress = 
                NetworkUtils.getLocalHost().getCanonicalHostName();
        } catch (final UnknownHostException e) {
            this.privateAddress = "";
        }
        final InetAddress pip = new PublicIpAddress().getPublicIpAddress();
        if (pip == null) {
            this.publicAddress = null;
        } else {
            this.publicAddress = pip.getHostAddress();
        }
    }

    public String getPublic() {
        return this.publicAddress;
    }
    
    public String getPrivate() {
        return this.privateAddress;
    }
    
    public void setPrivate(final String privateAddress) {
        this.privateAddress = privateAddress;
    }
    public void setPublic(final String publicAddress) {
        this.publicAddress = publicAddress;
    }
}
