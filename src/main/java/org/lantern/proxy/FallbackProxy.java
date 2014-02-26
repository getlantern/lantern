package org.lantern.proxy;

import org.codehaus.jackson.annotate.JsonIgnoreProperties;
import org.lantern.LanternUtils;
import org.lantern.S3Config;
import org.lantern.state.Peer.Type;
import org.littleshoot.util.FiveTuple.Protocol;

/**
 * Provided for backwards-compatibility with deserializing the json format from
 * {@link S3Config}.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public class FallbackProxy extends ProxyInfo {

    public FallbackProxy() {
        super();
        jid = LanternUtils.newURI("fallback-" + wanHost + "@getlantern.org");
        type = Type.cloud;
    }

    public void setIp(String ip) {
        this.wanHost = ip;
    }

    public void setPort(int port) {
        this.wanPort = port;
    }

    public void setAuth_token(String auth_token) {
        this.authToken = auth_token;
    }

    public void setProtocol(String protocol) {
        this.protocol = Protocol.valueOf(protocol.toUpperCase());
    }

}
