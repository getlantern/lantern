package org.lantern.event;

import org.lantern.state.Friend;

public class FriendStatusChangedEvent {

    private final Friend friend;

    public FriendStatusChangedEvent(final Friend friend) {
        this.friend = friend;
    }

    public Friend getFriend() {
        return friend;
    }
}
