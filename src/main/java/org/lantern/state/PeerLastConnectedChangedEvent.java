package org.lantern.state;

public class PeerLastConnectedChangedEvent {
    private Peer peer;

    PeerLastConnectedChangedEvent (Peer peer) {
        this.setPeer(peer);
    }

    public Peer getPeer() {
        return peer;
    }

    public void setPeer(Peer peer) {
        this.peer = peer;
    }
}
