package org.lantern;

import org.jivesoftware.smack.packet.Presence;

/**
 * Event propagated when there's a new user presence detected.
 */
public class AddPresenceEvent {

    private final String jid;
    private final Presence presence;

    public AddPresenceEvent(final String jid, final Presence presence) {
        this.jid = jid;
        this.presence = presence;
    }

    public String getJid() {
        return jid;
    }

    public Presence getPresence() {
        return presence;
    }

}
