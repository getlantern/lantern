package org.lantern.state;

import java.util.Collection;

import org.lantern.state.Friend.Status;

public interface FriendsHandler {

    void addFriend(String email);
    
    void removeFriend(String email);
    
    boolean isRejected(String from);

    boolean isFriend(String from);

    Collection<ClientFriend> getFriends();

    ClientFriend addOrFetchFriend(String email);

    void setStatus(Friend friend, Status status);

    void setPendingSubscriptionRequest(Friend friend, boolean subscribe);

    void addIncomingSubscriptionRequest(String from);

    void updateName(String address, String name);

}
