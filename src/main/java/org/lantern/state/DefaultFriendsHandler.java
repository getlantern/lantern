package org.lantern.state;

import java.io.IOException;
import java.net.URI;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicBoolean;

import javax.security.auth.login.CredentialException;

import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.packet.Presence;
import org.lantern.EmailAddressUtils;
import org.lantern.LanternUtils;
import org.lantern.MessageKey;
import org.lantern.Messages;
import org.lantern.Roster;
import org.lantern.XmppHandler;
import org.lantern.endpoints.FriendApi;
import org.lantern.event.Events;
import org.lantern.event.FriendStatusChangedEvent;
import org.lantern.event.PublicIpAndTokenEvent;
import org.lantern.event.ResetEvent;
import org.lantern.kscope.ReceivedKScopeAd;
import org.lantern.network.NetworkTracker;
import org.lantern.state.Friend.Status;
import org.lantern.state.Friend.SuggestionReason;
import org.lantern.ui.FriendNotificationDialog;
import org.lantern.ui.NotificationManager;
import org.lantern.util.Threads;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.littleshoot.util.ThreadUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
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

    private final AtomicBoolean friendsLoading = new AtomicBoolean(false);
    
    private final AtomicBoolean friendsLoaded = new AtomicBoolean(false);
    
    private final NotificationManager notificationManager;
    
    private final NetworkTracker<String, URI, ?> networkTracker;

    private Future<Map<String, ClientFriend>> loadedFriends;

    private final Messages msgs;
    
    @Inject
    public DefaultFriendsHandler(final Model model, final FriendApi api,
            final XmppHandler xmppHandler, 
            final NotificationManager notificationManager,
            final NetworkTracker<String, URI, ReceivedKScopeAd> networkTracker,
            final Messages msgs) {
        this.model = model;
        this.api = api;
        this.xmppHandler = xmppHandler;
        this.notificationManager = notificationManager;
        this.networkTracker = networkTracker;
        this.msgs = msgs;
        
        Events.register(this);
    }
    
    /**
     * The public IP is necessary because it lets us know if we're censored, 
     * which determines (along with whether or not we're in get mode) 
     * whether or not we should run with a proxy. We also need an oauth token
     * in order to hit the friends API, and this event tells us we have a
     * token.
     *
     * @param event The public ip and token event.
     */
    @Subscribe
    public void onPublicIpAndToken(final PublicIpAndTokenEvent event) {
        loadFriends();
    }
    
    private void loadFriends() {
        // If we're currently loading friends or have already successfully 
        // loaded friends, ignore this call.
        if (this.friendsLoading.getAndSet(true) || this.friendsLoaded.get()) {
            log.debug("Friends currently loading...");
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
                
                Collection<ClientFriend> friends = Collections.emptyList();
                try {
                    final Collection<ClientFriend> serverFriends = 
                            Arrays.asList(api.listFriends());
                    log.debug("All friends from server: {}", serverFriends);
                    for (final ClientFriend friend : serverFriends) {
                        tempFriends.put(friend.getEmail().toLowerCase(), friend);
                    }
                    log.debug("Finished loading friends");
                    friends = vals(tempFriends);
                    for (ClientFriend friend : friends) {
                        trackFriend(friend);
                    }
                    friendsLoaded.set(true);
                    return tempFriends;
                } catch (final IOException e) {
                    log.error("Could not list friends?", e);
                    friends = Collections.emptyList();
                    friendsLoaded.set(false);
                    return new HashMap<String, ClientFriend>();
                } catch (final CredentialException e) {
                    log.error("Could not list friends?", e);
                    friends = Collections.emptyList();
                    friendsLoaded.set(false);
                    return new HashMap<String, ClientFriend>();
                } finally {
                    friendsLoading.set(false);
                    model.setFriends(friends);
                    Events.sync(SyncPath.FRIENDS, friends);
                }
            }
        });
    }

    @Override
    public void addFriend(String email) {
        log.debug("Adding friend...");
        email = EmailAddressUtils.normalizedEmail(email);
        final ClientFriend existingFriend = getFriend(email);
        
        // If the friend previously didn't exist, friend them.
        if (existingFriend == null) {
            log.debug("Adding friend...");
            final ClientFriend temp = getOrCreateFriend(email);
            temp.setStatus(Status.friend);
            // We add the friend here even though it's not actually on the 
            // server -- we want the UI to get the processing state.
            put(temp, false);
            
            // Sync right away to update the UI. This also makes it as 
            // trusted right away.
            sync(temp);
            try {
                final ClientFriend cf = this.api.insertFriend(temp);
                
                // This will overwrite the temporary friend above.
                put(cf);
                try {
                    subscribe(email);
                } catch (final IOException e) {
                    this.msgs.error(MessageKey.ERROR_EMAILING_FRIEND, e, 
                            email);
                    fullRemove(cf);
                }
            } catch (final IOException e) {
                this.msgs.error(MessageKey.ERROR_ADDING_FRIEND, e, email);
                remove(email);
                syncFriends();
            } catch (final CredentialException e) {
                this.msgs.error(MessageKey.ERROR_ADDING_FRIEND, e, email);
                remove(email);
                syncFriends();
            }
            
        } else {
            log.debug("Friend is existing friend....");
            // We have an existing friend that's either a friend, rejected, or
            // pending.
            
            // Store the friend's original status -- we'll reset to this if
            // anything goes wrong.
            final Status originalStatus = existingFriend.getStatus();
            switch (originalStatus) {
            case friend:
                log.debug("Already friends with {}", email);
                msgs.info(MessageKey.ALREADY_ADDED, email);//"You have already added "+email+".");
                return;
            case pending:
                // Fall through -- handled in the same way as rejected.
            case rejected:
                existingFriend.setStatus(Status.friend);
                
                // We sync early here to give the user feedback right away.
                // Note this also has the side effect of generating an event
                // to remove any notification dialogs for the friend, for 
                // example.
                sync(existingFriend);
                Exception exc = null;
                try {
                    update(existingFriend);
                    xmppHandler.addToRoster(email);
                    return;
                } catch (IOException e) {
                    exc = e;
                } catch (CredentialException e) {
                    exc = e;
                }
                log.error("Could not friend?", exc);
                this.msgs.error(MessageKey.ERROR_UPDATING_FRIEND, exc, email);
                
                // Set the friend back to his or her original status!
                existingFriend.setStatus(originalStatus);
                sync(existingFriend);
                
                break;
            default:
                break;
            }
        }
    }

    private void fullRemove(final ClientFriend cf) {
        remove(cf.getEmail());
        // We treat this as all or nothing -- if a friend isn't 
        // invited successfully, remove them.
        try {
            this.api.removeFriend(cf.getId());
        } catch (final IOException ioe) {
            // We've already messaged the user about an error above.
            //log.error("Error removing "+email+".", ioe);
        } catch (final CredentialException e) {
            
        }
    }

    private void subscribe(final String email) throws IOException {
        if (this.xmppHandler != null) {
            try {
                this.xmppHandler.addToRoster(email);
                
                //if they have requested a subscription to us, we'll accept it.
                this.xmppHandler.subscribed(email);
    
                // We also automatically subscribe to them in turn so we know about
                // their presence.
                this.xmppHandler.subscribe(email);
            } catch (final IllegalStateException e) {
                throw new IOException("Error subscribing?", e);
            }
        } else {
            log.warn("No XMPP handler? Testing?");
            throw new IOException("No xmpp handler? Testing");
        }
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
    private void handlePeer(String email, final Presence pres) {
        email = EmailAddressUtils.normalizedEmail(email);
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
                try {
                    subscribe(email);
                } catch (IOException e) {
                    this.msgs.error(MessageKey.ERROR_ADDING_FRIEND, e);
                    friend.setStatus(Status.pending);
                    sync(friend);
                }
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
            friend.setReason(SuggestionReason.runningLantern);
            final ClientFriend onServer = insert(friend);
            syncFriends();
            
            // We only notify the user after the friend is safely stored on
            // the server as a pending friend. This also ensures any action
            // taken on that friend is referencing the actual server version
            // with a server ID.
            friendNotification(onServer);
        } catch (final IOException e) {
            log.warn("Could not update?", e);
        } catch (CredentialException e) {
            log.warn("Could not update?", e);
        }
    }

    private void friendNotification(final ClientFriend friend) {
        // Ox: friend notifications are disabled at the moment
        if (true) {
            return;
        }
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
            this.msgs.info(MessageKey.REMOVED_FRIEND, email);
        } catch (final IOException e) {
            this.msgs.error(MessageKey.ERROR_REMOVING_FRIEND, e, email);
            friend.setStatus(existingStatus);
            sync(friend);
        } catch (CredentialException e) {
            this.msgs.error(MessageKey.ERROR_REMOVING_FRIEND, e, email);
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

    private Map<String, ClientFriend> friends() {
        if (!friendsLoaded.get()) {
            loadFriends();
        }
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
        } catch (CredentialException e) {
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
            log.debug("Subscription request was from known friend");
            friend.setPendingSubscriptionRequest(true);
        } else {
            log.debug("Subscription request was from unknown user");
            // This subscription request is from someone we don't know, and it
            // may not even be from lantern.
            final ClientFriend newFriend = new ClientFriend(from);
            newFriend.setPendingSubscriptionRequest(true);
            put(newFriend, false);
        }
        syncFriends();
    }

    private ClientFriend insert(final ClientFriend friend) throws IOException, 
        CredentialException {
        final ClientFriend updated = this.api.insertFriend(friend);
        put(updated);
        return updated;
    }

    private ClientFriend update(final ClientFriend friend) throws IOException, 
        CredentialException {
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
            } catch (CredentialException e) {
                log.warn("Could not update name", e);
            }
        }
    }

    @Override
    public void stop() {
        log.debug("Stopping");
    }

    @Override
    public void syncFriends() {
        final Collection<ClientFriend> fr = getFriends();
        Events.sync(SyncPath.FRIENDS, fr);
    }
    
    @Subscribe
    public void onReset(final ResetEvent event) {
        this.friendsLoaded.set(false);
        this.friendsLoading.set(false);
        this.loadedFriends = null;
        this.friends().clear();
    }
    
}
