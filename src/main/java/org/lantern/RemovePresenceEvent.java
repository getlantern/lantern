package org.lantern;

/**
 * Event for when a presence is removed.
 */
public class RemovePresenceEvent {

    private final String jid;

    public RemovePresenceEvent(final String jid) {
        this.jid = jid;
    }

    public String getJid() {
        return jid;
    }

}
