package org.lantern.event;

import java.security.cert.X509Certificate;

import org.jboss.netty.channel.Channel;
import org.lantern.util.LanternTrafficCounter;

public class IncomingPeerEvent {


    private final Channel channel;
    private final LanternTrafficCounter trafficCounter;
    private final X509Certificate cert;

    public IncomingPeerEvent(final Channel channel,
            final LanternTrafficCounter trafficCounter,
            final X509Certificate cert) {
        this.channel = channel;
        this.trafficCounter = trafficCounter;
        this.cert = cert;
    }

    public Channel getChannel() {
        return channel;
    }

    public LanternTrafficCounter getTrafficCounter() {
        return trafficCounter;
    }

    public X509Certificate getCert() {
        return cert;
    }


}
