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

    private static volatile String PINNED_WAN_HOST;
    private static Object PINNED_WAN_HOST_MUTEX = new Object();
    
    private final FlashlightMasquerade masquerade;

    public FlashlightProxy(final String host, final int priority, 
            final FlashlightMasquerade masquerade,
            String cloudConfig,
            String cloudConfigCA) {
        super(LanternUtils.newURI("flashlight@"+ host),
                443,
                Protocol.TCP,
                ptProps(host, cloudConfig, cloudConfigCA),
                priority);
        this.masquerade = masquerade;
    }
    
    synchronized private static Properties ptProps(String host, String cloudConfig, String cloudConfigCA) {
        Properties props = new Properties();
        props.setProperty("type", "flashlight");
        props.setProperty(Flashlight.SERVER_KEY, host);
        props.setProperty(Flashlight.CLOUDCONFIG_KEY, cloudConfig);
        props.setProperty(Flashlight.CLOUDCONFIG_CA_KEY, cloudConfigCA);
        return props;
    }
    
    @Override
    public String getWanHost() {
        // We lazily initialize the wan host because dynamically
        // determining the host to use requires network access. So anything
        // calling this needs to be initialized as the result of network
        // access.
        if (StringUtils.isBlank(wanHost)) {
            // We pin the WAN host globally to avoid spawning multiple
            // flashlight instances with different WAN hosts
            synchronized (PINNED_WAN_HOST_MUTEX) {
                if (PINNED_WAN_HOST == null) {
                    PINNED_WAN_HOST = masquerade.determineMasqueradeHost()
                            .getKey();
                }
                wanHost = PINNED_WAN_HOST;
            }
            getPt().setProperty(Flashlight.MASQUERADE_KEY, wanHost);
        }
        return wanHost;
    }
    
}