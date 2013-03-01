package org.lantern.event;

import org.lantern.GoogleTalkState;

/**
 * Event for a change in authentication status.
 */
public class GoogleTalkStateEvent {

    private final GoogleTalkState state;
    private final String jid;

    public GoogleTalkStateEvent(String jid, final GoogleTalkState state) {
        this.jid = jid;
        this.state = state;
    }

    public GoogleTalkState getState() {
        return state;
    }

    public String getJid() {
        return jid;
    }

}
