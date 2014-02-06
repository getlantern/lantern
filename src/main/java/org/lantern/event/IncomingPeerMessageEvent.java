package org.lantern.event;

import org.jivesoftware.smack.packet.Presence;

public class IncomingPeerMessageEvent {

    private final Presence presence;

    public IncomingPeerMessageEvent(final Presence presence) {
        this.presence = presence;
    }

    public Presence getPresence() {
        return presence;
    }

}
