package org.lantern;

/**
 * Event propagated when there's a new user presence detected.
 */
public class AddPresenceEvent {

    private final String jid;
    private final LanternPresence presence;

    public AddPresenceEvent(final String jid, final LanternPresence presence) {
        this.jid = jid;
        this.presence = presence;
    }

    public String getJid() {
        return jid;
    }

    public LanternPresence getPresence() {
        return presence;
    }

}
