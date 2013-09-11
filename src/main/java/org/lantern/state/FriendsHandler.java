package org.lantern.state;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.codehaus.jackson.annotate.JsonCreator;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.annotate.JsonValue;
import org.lantern.state.Friend.Status;

public class FriendsHandler {


    private final Map<String, ClientFriend> friends =
        new ConcurrentHashMap<String, ClientFriend>();

    /**
     * Whether we need to sync to the server. This is only used to reduce the
     * number of friends syncs.
     */
    private boolean needsSync = true;

    public FriendsHandler() {}

    @JsonValue
    public Collection<ClientFriend> getFriends() {
        return vals(friends);
    }

    public void add(ClientFriend friend) {
        friends.put(friend.getEmail(), friend);
        needsSync = true;
    }

    @JsonCreator
    public static FriendsHandler create(final List<ClientFriend> list) {
        FriendsHandler friends = new FriendsHandler();
        for (final ClientFriend profile : list) {
            friends.friends.put(profile.getEmail(), profile);
        }
        return friends;
    }

    public void remove(final String email) {
        friends.remove(email.toLowerCase());
        needsSync = true;
    }

    private Collection<ClientFriend> vals(final Map<String, ClientFriend> map) {
        synchronized (map) {
            return map.values();
        }
    }

    public void clear() {
        friends.clear();
    }

    public ClientFriend get(String email) {
        return friends.get(email.toLowerCase());
    }

    public boolean needsSync() {
        return needsSync;
    }

    @JsonIgnore
    public void setNeedsSync(boolean needsSync) {
        this.needsSync = needsSync;
    }

    @JsonIgnore
    public void setStatus(String email, Status status) {
        email = email.toLowerCase();
        Friend friend = friends.get(email);
        if (friend.getStatus() != Status.friend) {
            friend.setStatus(status);
            this.needsSync = true;
        }
    }
}
