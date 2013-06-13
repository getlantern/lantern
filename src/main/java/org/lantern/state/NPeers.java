package org.lantern.state;

import org.lantern.annotation.Keep;

@Keep
public class NPeers {
    private PeerCount online = new PeerCount();
    private PeerCount ever = new PeerCount();

    public PeerCount getOnline() {
        return online;
    }

    public void setOnline(PeerCount online) {
        this.online = online;
    }

    public PeerCount getEver() {
        return ever;
    }

    public void setEver(PeerCount ever) {
        this.ever = ever;
    }
}