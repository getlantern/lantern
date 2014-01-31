package org.lantern.proxy;

import org.lantern.S3Config;
import org.littleshoot.util.FiveTuple.Protocol;

/**
 * Provided for backwards-compatibility with deserializing the json format from
 * {@link S3Config}.
 */
public class FallbackProxy extends ProxyInfo {

    public void setIp(String ip) {
        this.address = ip;
    }

    public void setAuth_token(String auth_token) {
        this.authToken = auth_token;
    }

    public void setProtocol(String protocol) {
        this.protocol = Protocol.valueOf(protocol.toUpperCase());
    }
}
