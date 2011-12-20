package org.lantern;

import java.net.UnknownHostException;

import org.lastbamboo.common.stun.client.PublicIpAddress;
import org.littleshoot.util.NetworkUtils;

/**
 * Stores data about the user's internet connection.
 */
public class Internet {

    public String getPublic() {
        return new PublicIpAddress().getPublicIpAddress().getHostAddress();
    }
    
    public String getPrivate() {
        try {
            return NetworkUtils.getLocalHost().getCanonicalHostName();
        } catch (final UnknownHostException e) {
            return "";
        }
    }
}
