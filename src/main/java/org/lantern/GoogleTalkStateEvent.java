package org.lantern;

/**
 * Event for a change in authentication status.
 */
public class GoogleTalkStateEvent {

    private final GoogleTalkState state;

    public GoogleTalkStateEvent(final GoogleTalkState state) {
        this.state = state;
    }

    public GoogleTalkState getState() {
        return state;
    }

}
