package org.lantern.event;

import java.net.InetSocketAddress;

import javax.security.cert.X509Certificate;

import org.lantern.proxy.GiveModeProxy;

/**
 * This event is fired whenever a peer connects to the {@link GiveModeProxy}.
 */
public class IncomingPeerEvent {

    private InetSocketAddress remoteAddress;
    private final X509Certificate cert;

    public IncomingPeerEvent(
            InetSocketAddress remoteAddress,
            X509Certificate cert) {
        super();
        this.remoteAddress = remoteAddress;
        this.cert = cert;
    }

    public InetSocketAddress getRemoteAddress() {
        return remoteAddress;
    }

    public X509Certificate getCert() {
        return cert;
    }

}
