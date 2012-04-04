package org.lantern;

import java.net.InetAddress;
import java.net.UnknownHostException;

import org.apache.commons.lang.StringUtils;
import org.lastbamboo.common.stun.client.PublicIpAddress;
import org.littleshoot.util.NetworkUtils;

/**
 * Stores data about the user's internet connection.
 */
public class Internet {

    private String privateAddress;
    private String publicAddress;

    public String getPublic() {
        if (StringUtils.isBlank(this.publicAddress)) {
            final InetAddress pip = new PublicIpAddress().getPublicIpAddress();
            if (pip == null) {
                this.publicAddress = null;
            } else {
                this.publicAddress = pip.getHostAddress();
            }
        }
        return this.publicAddress;
    }
    
    public String getPrivate() {
        if (StringUtils.isBlank(this.privateAddress)) {
            try {
                this.privateAddress = 
                    NetworkUtils.getLocalHost().getCanonicalHostName();
            } catch (final UnknownHostException e) {
                this.privateAddress = null;
            }
        }
        return this.privateAddress;
    }
}
