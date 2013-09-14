package org.lantern.state;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.SystemUtils;
import org.jivesoftware.smack.RosterEntry;
import org.lantern.Roster;
import org.lantern.XmppHandler;
import org.lantern.endpoints.FriendApi;
import org.lantern.event.Events;
import org.lantern.event.FriendStatusChangedEvent;
import org.lantern.event.RefreshTokenEvent;
import org.lantern.state.Friend.Status;
import org.lantern.state.Notification.MessageType;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.littleshoot.util.ThreadUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.common.io.Files;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class for dealing with all friends processing, including calling the remote
 * API, managing local copies of friends, etc.
 */
@Singleton
public class DefaultFriendsHandler implements FriendsHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Map<String, ClientFriend> friends =
        new ConcurrentHashMap<String, ClientFriend>();
    
    private final FriendApi api;
    private final Model model;

    private final XmppHandler xmppHandler;

    private final AtomicBoolean friendsLoaded = new AtomicBoolean(false);

    @Inject
    public DefaultFriendsHandler(final Model model, final FriendApi api,
            final XmppHandler xmppHandler) {
        this.model = model;
        this.api = api;
        this.xmppHandler = xmppHandler;
        
        // If we already have a refresh token, just use it to load friends.
        // Otherwise register for refresh token events.
        if (StringUtils.isNotBlank(model.getSettings().getRefreshToken())) {
            loadFriends();
        } else {
            Events.register(this);
        }
        handleBulkInvites();
    }

    @Subscribe
    public void onRefreshToken(final RefreshTokenEvent refresh) {
        loadFriends();
    }
    
    public void loadFriends() {
        if (this.friendsLoaded.getAndSet(true)) {
            return;
        }
        final Runnable runner = new Runnable() {
            @Override
            public void run() {
                log.debug("Loading friends");
                try {
                    final List<ClientFriend> serverFriends = api.listFriends();
                    log.debug("All friends from server: {}", serverFriends);
                    for (final ClientFriend friend : serverFriends) {
                        add(friend);
                    }
                    log.debug("Finished loading friends");
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
        log.debug("Adding friend...");
        final ClientFriend existingFriend = get(email);
        if (existingFriend != null && existingFriend.getStatus() == Status.friend) {
            log.debug("Already friends with {}", email);
            model.addNotification("You have already friended "+email+".",
              MessageType.info, 30);
            Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
            return;
        }
        
        final ClientFriend friend;
        
        // If the friend previously didn't exist or was rejected, friend them.
        if (existingFriend == null || existingFriend.getStatus() == Status.rejected) {
            log.debug("Adding or fetching friend...");
            
            // We want our local copy of friends to always reflect the server,
            // along with e-tags and everything else, so we always use the 
            // server version.
            final ClientFriend temp = makeFriend(email);
            temp.setStatus(Status.friend);
            try {
                friend = this.api.insertFriend(temp);
                add(friend);
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
            log.debug("Friend is existing friend....");
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
        log.debug("Syncing friend");
        //friend.setStatus(status);
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
    
    @Override
    public ClientFriend addOrFetchFriend(final String email) {
        final ClientFriend friend = makeFriend(email);
        add(friend);
        sync(friend, friend.getStatus());
        return friend;
    }
    
    private ClientFriend makeFriend(final String email) {
        ClientFriend friend = get(email);
        if (friend == null) {
            friend = new ClientFriend(email);
            final Roster roster = model.getRoster();
            final RosterEntry entry = roster.getEntry(email);
            if (entry != null) {
                friend.setName(entry.getName());
            }
        }
        return friend;
    }

    @Override
    public void removeFriend(final String email) {
        final ClientFriend friend = get(email);
        if (friend == null) {
            log.warn("Null friend?");
            return;
        }
        long id = friend.getId();
        try {
            this.api.removeFriend(id);
            friends.remove(email.toLowerCase());
            sync(friend, Status.rejected);
            model.addNotification("You have successfully rejected '"+email+"'.",
                MessageType.info, 30);
            Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
        } catch (final IOException e) {
            log.warn("Could not remove friend?");
        }
    }

    @Override
    public Collection<ClientFriend> getFriends() {
        return vals(friends);
    }

    public void add(final ClientFriend friend) {
        log.debug("Adding friend: {}", friend);
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

    private void handleBulkInvites() {
        final Runnable runner = new Runnable() {
            
            @Override
            public void run() {
                try {
                    Thread.sleep(40000);
                } catch (final InterruptedException e) {
                }
                checkForBulkInvites();
            }
        };
        final Thread t = new Thread(runner, "Bulk-Invites-Thread");
        t.setDaemon(true);
        t.start();
    }
    
    /**
     * See if there's a bulk invite file to process, and process it if so.
     */
    private void checkForBulkInvites() {
        final File file = new File(SystemUtils.USER_HOME, 
            "lantern-bulk-friends.txt");
        if (!file.isFile()) {
            return;
        }
        final File processed = 
            new File(file.getParentFile(), file.getName()+".processed");
        
        try {
            Files.move(file, processed);
        } catch (final IOException e) {
            log.error("Could not move bulk invites file?", e);
            return;
        }
        
        if (!this.xmppHandler.isLoggedIn()) {
            log.debug("Not logged in?");
            return;
        }
        BufferedReader br = null;
        try {
            br = new BufferedReader(new InputStreamReader(new FileInputStream(file)));
            String email = br.readLine();
            while (StringUtils.isNotBlank(email)) {
                log.debug("Inviting {}", email);
                if (!email.contains("@")) {
                    log.error("Not an email: {}", email);
                    break;
                }
                
                if (email.startsWith("#")) {
                    log.debug("Email commented out: {}", email);
                    email = br.readLine();
                    continue;
                }
                
                final Friend friend = makeFriend(email.trim());
                model.addNotification("BULK-EMAIL: An email will be sent to "+email+" "+
                    "with a notification that you friended them. "+
                    "If they do not yet have a Lantern invite, they will "+
                    "be invited when the network can accommodate them.",
                    MessageType.info, 5);
                Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
                invite(friend, false);
                email = br.readLine();
                
                // Wait a bit between each one!
                try {
                    Thread.sleep(6000);
                } catch (InterruptedException e) {
                }
            }
        } catch (final IOException e) {
            log.error("Could not find file?", e);
        } finally {
            IOUtils.closeQuietly(br);
        }
    }
}
