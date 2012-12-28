package org.lantern.event;

import org.lantern.PeerProxyManager;

public class ConnectedPeersEvent {

    private final PeerProxyManager peerProxyManager;

    public ConnectedPeersEvent(final PeerProxyManager peerProxyManager) {
        this.peerProxyManager = peerProxyManager;
    }

    public PeerProxyManager getPeerProxyManager() {
        return peerProxyManager;
    }

}
