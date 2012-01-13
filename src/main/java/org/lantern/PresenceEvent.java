package org.lantern;

import org.jivesoftware.smack.packet.Presence;

/**
 * Event propagated when there's a new user presence detected.
 */
public class PresenceEvent {

    private final String jid;
    private final Presence presence;

    public PresenceEvent(final String jid, final Presence pres) {
        this.jid = jid;
        this.presence = pres;
    }

    public String getJid() {
        return jid;
    }

    public Presence getPresence() {
        return presence;
    }

}
