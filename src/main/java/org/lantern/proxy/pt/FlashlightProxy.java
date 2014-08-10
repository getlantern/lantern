package org.lantern.proxy.pt;

import java.util.Properties;

import org.apache.commons.lang3.StringUtils;
import org.lantern.LanternUtils;
import org.lantern.proxy.FallbackProxy;
import org.littleshoot.util.FiveTuple.Protocol;

/**
 * Specialized fallback proxy for flashlight. In particular, this lazily
 * initializes the WAN host because it dynamically determines it based on the
 * available candidates.
 */
public class FlashlightProxy extends FallbackProxy {

    private final FlashlightMasquerade masquerade;

    public FlashlightProxy(final String host, final int priority, 
            final FlashlightMasquerade masquerade) {
        this.masquerade = masquerade;
        final Properties props = new Properties();
        
        props.setProperty("type", "flashlight");
        props.setProperty(Flashlight.SERVER_KEY, host);
        
        setPt(props);
        setJid(LanternUtils.newURI("flashlight@"+ host));
        setPort(443);
        setProtocol(Protocol.TCP);
        setPriority(priority);
    }
    
    @Override
    public String getWanHost() {
        // We lazily initialize the wan host because dynamically
        // determining the host to use requires network access. So anything
        // calling this needs to be initialized as the result of network
        // access.
        if (StringUtils.isBlank(wanHost)) {
            wanHost = masquerade.determineMasqueradeHost().getKey();
            getPt().setProperty(Flashlight.MASQUERADE_KEY, wanHost);
        }
        return wanHost;
    }
    
}