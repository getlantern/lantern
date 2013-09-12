package org.lantern.state;

import java.util.Collection;

import org.lantern.state.Friend.Status;

public interface FriendsHandler {

    boolean isRejected(String from);

    boolean isFriend(String from);

    Collection<ClientFriend> getFriends();

    ClientFriend addOrFetchFriend(String email);

    void setStatus(Friend friend, Status status);

}
