package org.lantern.event;

import org.lantern.state.Friend;

public class FriendStatusChangedEvent {

    private Friend friend;

    public FriendStatusChangedEvent(Friend friend) {
        this.setFriend(friend);
    }

    public Friend getFriend() {
        return friend;
    }

    public void setFriend(Friend friend) {
        this.friend = friend;
    }
}
