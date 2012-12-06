package org.lantern.event;

import org.jivesoftware.smack.packet.Presence;

public class UpdatePresenceEvent {

    private final Presence presence;

    public UpdatePresenceEvent(final Presence presence) {
        this.presence = presence;
    }

    public Presence getPresence() {
        return presence;
    }

}
