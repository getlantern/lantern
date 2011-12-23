package org.lantern;

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
        this.publicAddress =
            new PublicIpAddress().getPublicIpAddress().getHostAddress();
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
