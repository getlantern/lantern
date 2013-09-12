package org.lantern.state;

import java.io.IOException;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.jivesoftware.smack.RosterEntry;
import org.lantern.JsonUtils;
import org.lantern.Roster;
import org.lantern.XmppHandler;
import org.lantern.endpoints.FriendApi;
import org.lantern.event.Events;
import org.lantern.event.FriendStatusChangedEvent;
import org.lantern.event.RefreshTokenEvent;
import org.lantern.state.Friend.Status;
import org.lantern.state.Notification.MessageType;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;

public class DefaultFriendsHandler implements FriendsHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Map<String, ClientFriend> friends =
        new ConcurrentHashMap<String, ClientFriend>();
    
    private final FriendApi api;
    private final Model model;

    private final XmppHandler xmppHandler;

    private final ModelUtils modelUtils;

    @Inject
    public DefaultFriendsHandler(final Model model, final FriendApi api,
            final XmppHandler xmppHandler, final ModelUtils modelUtils) {
        this.model = model;
        this.api = api;
        this.xmppHandler = xmppHandler;
        this.modelUtils = modelUtils;
        Events.register(this);
    }

    @Subscribe
    public void loadFriends(final RefreshTokenEvent refresh) {
        final Runnable runner = new Runnable() {
            @Override
            public void run() {
                try {
                    final List<ClientFriend> serverFriends = api.listFriends();
                    for (final ClientFriend friend : serverFriends) {
                        add(friend);
                    }
                } catch (final IOException e) {
                    log.error("Could not list friends?");
                }
            }
        };
        final Thread t = new Thread(runner, "Friends-Fetching-Thread");
        t.setDaemon(true);
        t.start();
    }

    @Override
    public void addFriend(final String email) {
        //final String email = email(json);
        addFriend(email, true);
    }
    
    private void addFriend(final String email, final boolean subscribe) {
        final Friend existingFriend = get(email);
        if (existingFriend != null && existingFriend.getStatus() == Status.friend) {
            log.debug("Already friends with {}", email);
            model.addNotification("You have already friended "+email+".",
              MessageType.info, 30);
            Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
            return;
        }
        
        final Friend friend;
        
        // If the friend previously didn't exist or was rejected, friend them.
        if (existingFriend == null || existingFriend.getStatus() == Status.rejected) {
            final ClientFriend temp = addOrFetchFriend(email);
            try {
                friend = this.api.insertFriend(temp);
            } catch (final IOException e) {
                model.addNotification("Error adding friend '"+email+
                    "'. Do you still have an Internet connection?",
                    MessageType.error, 30);
                Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
                return;
            }
            try {
                invite(friend, true);
            } catch (final IOException e) {
                return;
            }
        } else {
            friend = existingFriend;
        }
        
        // Otherwise, it's an existing friend that's likely pending.
        sync(friend, Status.friend);
        
        if (subscribe && this.xmppHandler != null) {
            try {
                //if they have requested a subscription to us, we'll accept it.
                this.xmppHandler.subscribed(email);
    
                // We also automatically subscribe to them in turn so we know about
                // their presence.
                this.xmppHandler.subscribe(email);
            } catch (final IllegalStateException e) {
                log.error("IllegalStateException while friending " +
                    "(you are probably offline)", e);
                model.addNotification("Error subscribing to friend: "+email+
                    ". Could you have lost your Internet connection?",
                    MessageType.error, 30);
                Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
            }
        }
    }

    private void sync(final Friend friend, final Status status) {
        friend.setStatus(status);
        //friends.setNeedsSync(true);
        Events.asyncEventBus().post(new FriendStatusChangedEvent(friend));
        Events.sync(SyncPath.FRIENDS, getFriends());
    }
    
    private void invite(final Friend friend, final boolean addToRoster) 
            throws IOException {
        final String email = friend.getEmail();
        
        // Can be null for testing...
        if (this.xmppHandler == null) {
            log.error("Null XMPP handler");
            return;
        }
        try {
            this.xmppHandler.sendInvite(friend, false, addToRoster);
            // we need to mark this email as pending, in case
            // our invite gets lost.
            model.addPendingInvite(email);
            model.addNotification("An email will be sent to "+email+" "+
                "with a notification that you friended them. "+
                "If they do not yet have a Lantern invite, they will "+
                "be invited when the network can accommodate them.",
                MessageType.info, 30);
            Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
        } catch (final Throwable e) {
            log.error("failed to send invite: ", e);
            model.addNotification("Failed to successfully become Lantern " +
                "friends with '"+email+"'. The cause was described as '"+e.getMessage()+"'.",
                MessageType.error, 30);
            Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
            model.addPendingInvite(email);
            throw new IOException("Invite failed", e);
        }

    }
    
    public ClientFriend addOrFetchFriend(final String email) {
        ClientFriend friend = get(email);
        if (friend == null) {
            friend = new ClientFriend(email);
            final Roster roster = model.getRoster();
            final RosterEntry entry = roster.getEntry(email);
            if (entry != null) {
                friend.setName(entry.getName());
            }
            add(friend);
        }
        return friend;
    }

    @Override
    public void removeFriend(final String email) {
        
    }

    @Override
    public Collection<ClientFriend> getFriends() {
        return vals(friends);
    }

    public void add(final ClientFriend friend) {
        friends.put(friend.getEmail().toLowerCase(), friend);
    }

    /*
    @JsonCreator
    public static FriendsHandler create(final List<ClientFriend> list) {
        FriendsHandler friends = new FriendsHandler();
        for (final ClientFriend profile : list) {
            friends.friends.put(profile.getEmail(), profile);
        }
        return friends;
    }
    */

    public void remove(final String email) {
        friends.remove(email.toLowerCase());
    }

    private Collection<ClientFriend> vals(final Map<String, ClientFriend> map) {
        synchronized (map) {
            return map.values();
        }
    }

    public void clear() {
        friends.clear();
    }

    public ClientFriend get(final String email) {
        return friends.get(email.toLowerCase());
    }

    public void setStatus(final String email, final Status status) {
        final Friend friend = get(email.toLowerCase());
        if (friend == null) {
            log.error("Could not locate friend at: "+email);
            return;
        }
        setStatus(friend, status);
        /*
        if (friend.getStatus() != Status.friend) {
            friend.setStatus(status);
            try {
                this.api.updateFriend(friend);
            } catch (IOException e) {
                model.addNotification("Could not update friend status for '"+email+"'.",
                    MessageType.info, 30);
                Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
            }
        }
        */
    }
    
    public boolean isFriend(final String from) {
        final String email = XmppUtils.jidToUser(from);
        final Friend friend = get(email);
        return friend != null && friend.getStatus() == Status.friend;
    }
    
    public boolean isRejected(final String from) {
        final String email = XmppUtils.jidToUser(from);
        final Friend friend = get(email);
        return friend != null && friend.getStatus() == Status.rejected;
    }

    @Override
    public void setStatus(final Friend friend, final Status status) {
        if (friend.getStatus() == status) {
            log.debug("No change in status -- ignoring call");
            return;
        }
        friend.setStatus(status);
        update(friend);
    }


    @Override
    public void setPendingSubscriptionRequest(final Friend friend, 
            final boolean subscribe) {
        friend.setPendingSubscriptionRequest(subscribe);
        update(friend);
    }


    private void update(final Friend friend) {
        try {
            this.api.updateFriend(friend);
        } catch (final IOException e) {
            log.error("Could not update friend?", e);
            model.addNotification("Could not update friend status for '"+friend.getEmail()+"'.",
                MessageType.info, 30);
            Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
        }
    }
    
    @Override
    public void addIncomingSubscriptionRequest(final String from) {
        log.debug("Adding subscription request");
        final Friend friend = get(from);
        if (friend != null) {
            setPendingSubscriptionRequest(friend, true);
        } else {
            final ClientFriend newFriend = new ClientFriend(from);
            newFriend.setPendingSubscriptionRequest(true);
            add(newFriend);
        }
    }


    @Override
    public void updateName(String address, String name) {
        final Friend friend = get(address);
        if (friend != null && !name.equals(friend.getName())) {
            friend.setName(name);
            update(friend);
        }
    }
}
