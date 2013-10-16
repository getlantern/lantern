package org.lantern.state;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URI;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicBoolean;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.SystemUtils;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.packet.Presence;
import org.lantern.LanternUtils;
import org.lantern.Roster;
import org.lantern.XmppHandler;
import org.lantern.endpoints.FriendApi;
import org.lantern.event.Events;
import org.lantern.event.FriendStatusChangedEvent;
import org.lantern.event.RefreshTokenEvent;
import org.lantern.kscope.ReceivedKScopeAd;
import org.lantern.network.NetworkTracker;
import org.lantern.state.Friend.Status;
import org.lantern.state.Notification.MessageType;
import org.lantern.ui.FriendNotificationDialog;
import org.lantern.ui.NotificationManager;
import org.lantern.util.Threads;
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
    
    private final FriendApi api;
    private final Model model;

    private final XmppHandler xmppHandler;

    private final AtomicBoolean friendsLoaded = new AtomicBoolean(false);
    
    private final NotificationManager notificationManager;
    
    private final NetworkTracker<String, URI, ?> networkTracker;

    private Future<Map<String, ClientFriend>> loadedFriends;
    
    
    @Inject
    public DefaultFriendsHandler(final Model model, final FriendApi api,
            final XmppHandler xmppHandler, 
            final NotificationManager notificationManager,
            final NetworkTracker<String, URI, ReceivedKScopeAd> networkTracker) {
        this.model = model;
        this.api = api;
        this.xmppHandler = xmppHandler;
        this.notificationManager = notificationManager;
        this.networkTracker = networkTracker;
        
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
        log.debug("Got refresh token -- loading friends");
        loadFriends();
    }
    
    private void loadFriends() {
        if (this.friendsLoaded.getAndSet(true)) {
            log.debug("Friends already loaded...");
            return;
        }
        final ExecutorService friendsLoader = 
                Executors.newSingleThreadExecutor(
                        Threads.newDaemonThreadFactory("Friends-Loader"));
        
        // We make this a future because we only want to manage friends based
        // on the server's copy. So any local changes wait for that copy to
        // be resolved before manipulating friends.
        loadedFriends = friendsLoader.submit(new Callable<Map<String, ClientFriend>>() {
            @Override
            public Map<String, ClientFriend> call() throws IOException {
                log.debug("Loading friends");
                final Map<String, ClientFriend> tempFriends =
                        new ConcurrentHashMap<String, ClientFriend>();
                try {
                    final List<ClientFriend> serverFriends = api.listFriends();
                    log.debug("All friends from server: {}", serverFriends);
                    for (final ClientFriend friend : serverFriends) {
                        tempFriends.put(friend.getEmail().toLowerCase(), friend);
                    }
                    log.debug("Finished loading friends");
                    final Collection<ClientFriend> friends = vals(tempFriends);
                    model.setFriends(friends);
                    for (ClientFriend friend : friends) {
                        trackFriend(friend);
                    }
                    Events.sync(SyncPath.FRIENDS, friends); 
                    return tempFriends;
                } catch (final IOException e) {
                    log.error("Could not list friends?", e);
                    throw e;
                }
            }
        });
    }

    @Override
    public void addFriend(final String email) {
        addFriend(email, true);
    }
    
    private void addFriend(final String email, final boolean subscribe) {
        log.debug("Adding friend...");
        final ClientFriend existingFriend = getFriend(email);
        
        final ClientFriend friend;
        
        // If the friend previously didn't exist or was rejected, friend them.
        if (existingFriend == null) {
            log.debug("Adding friend...");
            friend = addAndInvite(email);
        } else {
            log.debug("Friend is existing friend....");
            // We have an existing friend that's either a friend, rejected, or
            // pending.
            friend = existingFriend;
            
            // Store the friend's original status -- we'll reset to this if
            // anything goes wrong.
            final Status originalStatus = friend.getStatus();
            switch (originalStatus) {
            case friend:
                log.debug("Already friends with {}", email);
                info("You have already added "+email+".");
                return;
            case pending:
                // Fall through -- handled in the same way as rejected.
            case rejected:
                friend.setStatus(Status.friend);
                
                // We sync early here to give the user feedback right away.
                // Note this also has the side effect of generating an event
                // to remove any notification dialogs for the friend, for 
                // example.
                sync(friend);
                try {
                    update(friend);
                } catch (IOException e) {
                    log.error("Could not friend?", e);
                    error("Error adding "+email+".");
                    
                    // Set the friend back to his or her original status!
                    friend.setStatus(originalStatus);
                    sync(friend);
                    return;
                }
                try {
                    invite(friend, true);
                } catch (final IOException e) {
                    error("Error adding "+email+".", e);
                    
                    // Set the friend back to his or her original status!
                    friend.setStatus(originalStatus);
                    sync(friend);
                    return;
                }

                break;
            default:
                break;
            }
        }
        
        sync(friend);
        
        // Note this also happens for existing friends, but no harm done.
        if (subscribe) {
            subscribe(email);
        }
    }

    private void subscribe(final String email) {
        if (this.xmppHandler != null) {
            try {
                //if they have requested a subscription to us, we'll accept it.
                this.xmppHandler.subscribed(email);
    
                // We also automatically subscribe to them in turn so we know about
                // their presence.
                this.xmppHandler.subscribe(email);
            } catch (final IllegalStateException e) {
                error("Error connecting to "+email+".", e);
            }
        } else {
            log.warn("No XMPP handler? Testing?");
        }
    }
    
    private void unsubscribe(final String email) {
        if (this.xmppHandler != null) {
            try {
                this.xmppHandler.unsubscribed(email);
                this.xmppHandler.unsubscribe(email);
            } catch (final IllegalStateException e) {
                log.error("Error unsubscribing from "+email, e);
            }
        } else {
            log.warn("No XMPP handler? Testing?");
        }
    }

    private ClientFriend addAndInvite(final String email) {
        // We want our local copy of friends to always reflect the server,
        // along with e-tags and everything else, so we always use the 
        // server version.
        final ClientFriend temp = getOrCreateFriend(email);
        temp.setStatus(Status.friend);
        try {
            final ClientFriend friend = this.api.insertFriend(temp);
            put(friend);
            try {
                invite(friend, true);
            } catch (final IOException e) {
                error("Error adding "+email+ ".", e);
                
                // We treat this as all or nothing -- if a friend isn't 
                // invited successfully, remove them.
                try {
                    this.api.removeFriend(friend.getId());
                } catch (final IOException ioe) {
                    log.error("Error removing "+email+".", ioe);
                }
            }
            return friend;
        } catch (final IOException e) {
            error("Error adding "+email+".", e);
        }
        return null;

    }

    private void sync(final ClientFriend friend) {
        log.debug("Syncing friend");
        //friend.setStatus(status);
        //friends.setNeedsSync(true);
        Events.asyncEventBus().post(new FriendStatusChangedEvent(friend));
        trackFriend(friend);
        syncFriends();
    }
    
    private void trackFriend(ClientFriend friend) {
        if (isFriend(friend)) {
            networkTracker.userTrusted(friend.getEmail());
        } else if (isRejected(friend)){
            networkTracker.userUntrusted(friend.getEmail());
        }
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
            info("Added "+email+". If this account is not yet in the private beta, "+
                "it will be invited upon admin approval.");
        } catch (final Throwable e) {
            error("Error adding "+email+".", e);
            throw new IOException("Invite failed", e);
        }
    }
    
    private final ExecutorService service = Executors.newSingleThreadExecutor(
            Threads.newDaemonThreadFactory("Peer-Running-Updater"));
    
    @Override
    public void peerRunningLantern(final String email, 
            final Presence pres) {
        log.debug("Adding peer running lantern...");
        service.submit(new Runnable () {

            @Override
            public void run() {
                handlePeer(email, pres);
            }
        });
    }
    
    /**
     * Handles a peer presence -- should only be called from an executor where
     * all peer presence events are queued in order.
     * 
     * @param email The email address of the peer
     * @param pres The presence event
     */
    private void handlePeer(final String email, final Presence pres) {
        final ClientFriend existing = getFriend(email);
        if (existing != null) {
            log.debug("We already know about the peer...");
            
            // Here we just update the peer with the live presence information.
            if (pres.isAvailable()) {
                existing.setLoggedIn(true);
            } else {
                existing.setLoggedIn(false);
            }
            existing.setMode(pres.getMode());
            if (isFriend(existing) || isRejected(existing)) {
                log.debug("Peer is a friend or rejected, not adding a notification");
                return;
            } else {
                log.debug("Potentially adding notification...");
                friendNotification(existing);
                return;
            }
        } else {
            log.debug("Processing presence for peer we don't know about: "+email);
            presenceForNewPeer(email, pres);
        }
    }

    private void presenceForNewPeer(final String email, final Presence pres) {
        final ClientFriend friend = new ClientFriend(email);
        
        // If it's a presence notification from ourselves in another Lantern
        // instance, make extra sure we're subscribed to each other and are
        // friends.
        if (email.equals(model.getProfile().getEmail())) {
            //we'll assume that a user already trusts themselves
            if (friend.getStatus() != Status.friend) {
                friend.setStatus(Status.friend);
                sync(friend);
                subscribe(email);
            }
            return;
        }

        final Roster roster = model.getRoster();
        final RosterEntry entry = roster.getEntry(email);
        if (entry != null) {
            friend.setName(entry.getName());
        }
        
        if (pres.isAvailable()) {
            friend.setLoggedIn(true);
        } else {
            friend.setLoggedIn(false);
        }
        friend.setMode(pres.getMode());
        
        // We actually update the server here because we've received a 
        // presence notification from a peer running lantern, so we want to
        // record that for future sessions because we might not see them
        // running Lantern right away again.
        try {
            
            // Make sure we don't add a new friend if we already know about 
            // them.
            final ClientFriend existing = getFriend(friend.getEmail());
            if (existing != null) {
                log.debug("We already know about the friend");
                return;
            }
            final ClientFriend onServer = insert(friend);
            syncFriends();
            
            // We only notify the user after the friend is safely stored on
            // the server as a pending friend. This also ensures any action
            // taken on that friend is referencing the actual server version
            // with a server ID.
            friendNotification(onServer);
        } catch (final IOException e) {
            log.warn("Could not update?", e);
        }
    }

    private void friendNotification(final ClientFriend friend) {
        final Settings settings = model.getSettings();
        if (!settings.isUiEnabled()) {
            log.debug("UI not enabled");
            return;
        }
        if (friend.shouldNotifyAgain() && settings.isShowFriendPrompts()
                && model.isSetupComplete()) {
            if (notificationManager == null) {
                log.debug("Null notification dialog -- testing?");
                return;
            }
            if (!notificationManager.shouldNotify()) {
                log.debug("Not notifying");
                return;
            }
            log.debug("Notifying");
            final FriendNotificationDialog notification = 
                new FriendNotificationDialog(notificationManager, 
                    DefaultFriendsHandler.this, friend);
            notificationManager.addNotification(notification);
        }
    }
    
    private void put(final ClientFriend friend) {
        put(friend, true);
    }
    
    private void put(final ClientFriend friend, final boolean checkId) {
        log.debug("Adding friend: {}", friend);
        if (checkId && friend.getId() == 0L) {
            log.warn("Adding friend that's not added to the server?");
            return;
        }
        friends().put(friend.getEmail().toLowerCase(), friend);
    }

    private ClientFriend getOrCreateFriend(final String email) {
        final ClientFriend friend = getFriend(email);
        if (friend != null) {
            return friend;
        }
        final ClientFriend newFriend = new ClientFriend(email);
        final Roster roster = model.getRoster();
        final RosterEntry entry = roster.getEntry(email);
        if (entry != null) {
            newFriend.setName(entry.getName());
        }
        return newFriend;
    }

    @Override
    public void removeFriend(final String mixedCase) {
        final String email = mixedCase.toLowerCase();
        final ClientFriend friend = getFriend(email);
        if (friend == null) {
            log.warn("Null friend?");
            return;
        }
        
        final Status existingStatus = friend.getStatus();
        try {
            friend.setStatus(Status.rejected);
            sync(friend);
            final ClientFriend updated = this.api.updateFriend(friend);
            put(updated);
            info(email+" has been removed.");
        } catch (final IOException e) {
            error("Error removing "+email+".", e);
            friend.setStatus(existingStatus);
            sync(friend);
        }
        
        // TODO: We should really also unsubscribe from them here and
        // should not allow them to subscribe to us **only if Lantern was the
        // one that originally managed the subscriptions.**
        //unsubscribe(friend.getEmail());
    }

    @Override
    public Collection<ClientFriend> getFriends() {
        return vals(friends());
    }

    public void remove(final String email) {
        friends().remove(email.toLowerCase());
    }

    private Collection<ClientFriend> vals(final Map<String, ClientFriend> map) {
        synchronized (map) {
            return map.values();
        }
    }

    public void clear() {
        friends().clear();
    }

    private Map<String, ClientFriend> friends() {
        try {
            final Map<String, ClientFriend> friends = loadedFriends.get();
            return friends;
        } catch (final InterruptedException e) {
            log.warn("Could not get friends?", e);
            return new HashMap<String, ClientFriend>();
        } catch (final ExecutionException e) {
            log.warn("Could not get friends?", e);
            return new HashMap<String, ClientFriend>();
        }
    }

    @Override
    public ClientFriend getFriend(final String email) {
        return friends().get(email.toLowerCase());
    }
    
    @Override
    public boolean isFriend(final String from) {
        final String email = XmppUtils.jidToUser(from);
        final ClientFriend friend = getFriend(email);
        return isFriend(friend);
    }
    
    private boolean isFriend(final Friend friend) {
        return friend != null && friend.getStatus() == Status.friend;
    }
    
    @Override
    public boolean isRejected(final String from) {
        final String email = XmppUtils.jidToUser(from);
        final ClientFriend friend = getFriend(email);
        return isRejected(friend);
    }
    
    
    private boolean isRejected(final ClientFriend friend) {
        return friend != null && friend.getStatus() == Status.rejected;
    }

    @Override
    public void setStatus(final ClientFriend friend, final Status status) {
        final Status originalStatus = friend.getStatus();
        if (originalStatus == status) {
            log.debug("No change in status -- ignoring call");
            return;
        }
        if (!isOnServer(friend)) {
            return;
        }
        
        friend.setStatus(status);
        sync(friend);
        try {
            update(friend);
        } catch (final IOException e) {
            friend.setStatus(originalStatus);
            sync(friend);
        }
    }

    
    private boolean isOnServer(final ClientFriend friend) {
        if (friend.getId() == null) {
            log.error("Friend has no ID? "+ThreadUtils.dumpStack());
            return false;
        }
        return true;
    }

    @Override
    public void addIncomingSubscriptionRequest(final String from) {
        log.debug("Adding subscription request from: {}", from);
        if (LanternUtils.isAnonymizedGoogleTalkAddress(from)) {
            // This was a subscription request between these users from outside
            // Lantern of the form:
            // 0po8orrkoxnba3oobvgvyd70ne@public.talk.google.com
            // We just ignore it.
            log.debug("Ignoring request");
            return;
        }
        final ClientFriend friend = getFriend(from);
        // Note we do not update the server with this change -- XMPP takes care
        // of delivering subscription requests, so we just track them on the
        // client.
        if (friend != null) {
            friend.setPendingSubscriptionRequest(true);
        } else {
            // This subscription request is from someone we don't know, and it
            // may not even be from lantern.
            final ClientFriend newFriend = new ClientFriend(from);
            newFriend.setPendingSubscriptionRequest(true);
            put(newFriend, false);
        }
        syncFriends();
    }

    private ClientFriend insert(final ClientFriend friend) throws IOException {
        final ClientFriend updated = this.api.insertFriend(friend);
        put(updated);
        return updated;
    }

    private ClientFriend update(final ClientFriend friend) throws IOException {
        final ClientFriend updated = this.api.updateFriend(friend);
        put(updated);
        return updated;
    }

    @Override
    public void updateName(final String address, final String name) {
        final ClientFriend friend = getFriend(address);
        if (friend != null && !name.equals(friend.getName())) {
            if (!isOnServer(friend)) {
                return;
            }
            friend.setName(name);
            try {
                update(friend);
            } catch (IOException e) {
                log.warn("Could not update name", e);
            }
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
    

    private void info(final String msg) {
        msg(msg, MessageType.info);
    }
    
    private void warn(final String msg) {
        msg(msg, MessageType.warning);
    }
    
    private void error(final String msg, final Throwable t) {
        log.error(msg, t);
        msg(msg, MessageType.error);
    }
    
    private void msg(final String msg, final MessageType type) {
        model.addNotification(msg, type, 30);
        Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
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
                
                final Friend friend = getOrCreateFriend(email.trim());
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

    @Override
    public void syncFriends() {
        final Collection<ClientFriend> fr = getFriends();
        Events.sync(SyncPath.FRIENDS, fr);
    }
}
