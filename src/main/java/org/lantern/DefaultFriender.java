package org.lantern;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.Collection;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.SystemUtils;
import org.lantern.event.Events;
import org.lantern.event.FriendStatusChangedEvent;
import org.lantern.state.Friend;
import org.lantern.state.Friend.Status;
import org.lantern.state.Friends;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;
import org.lantern.state.Notification.MessageType;
import org.lantern.state.SyncPath;
import org.lastbamboo.common.p2p.P2PConnectionEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.common.io.Files;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class for handling all friend management.
 */
@Singleton
public class DefaultFriender implements Friender {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final Model model;
    private final XmppHandler xmppHandler;
    private final ModelUtils modelUtils;

    @Inject
    public DefaultFriender(final Model model, final XmppHandler xmppHandler,
        final ModelUtils modelUtils) {
        this.model = model;
        this.xmppHandler = xmppHandler;
        this.modelUtils = modelUtils;
        Events.register(this);
        
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
    

    @Subscribe
    public void onP2PConnectionEvent(P2PConnectionEvent e) {
        if (e.isConnected()) {
            // resend invites
            final Friends friends = model.getFriends();
            final Collection<String> pendingInvites = new ArrayList<String>(
                    model.getPendingInvites());
            for (final String email : pendingInvites) {
                log.info("Resending pending invite to {}", email);
                Friend friend = friends.get(email);
                xmppHandler.sendInvite(friend, true, true);
            }
        }

    }

    private void invite(final Friend friend, final boolean addToRoster) 
            throws IOException {
        final String email = friend.getEmail();
        try {
            xmppHandler.sendInvite(friend, false, addToRoster);
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
    public void removeFriend(final String json) {
        final String email = email(json);
        removeFriendByEmail(email);
    }

    private void removeFriendByEmail(final String email) {
        final Friends friends = model.getFriends();
        final Friend friend = friends.get(email);
        sync(friend, Status.rejected);
        model.addNotification("You have successfully rejected '"+email+"'.",
            MessageType.info, 30);
        Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
    }

    private String email(final String json) {
        return JsonUtils.getValueFromJson("email", json).toLowerCase();
    }

    @Override
    public void addFriend(final String json) {
        addFriendByEmail(email(json), true);
    }

    private void addFriendByEmail(final String email, final boolean subscribe) {
        final Friends friends = model.getFriends();
        Friend friend = friends.get(email);
        if (friend != null && friend.getStatus() == Status.friend) {
            log.debug("Already friends with {}", email);
            model.addNotification("You have already friended "+email+".",
              MessageType.info, 30);
            Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
            return;
        }
        
        // If the friend previously didn't exist or was rejected, friend them.
        if (friend == null || friend.getStatus() == Status.rejected) {
            friend = modelUtils.makeFriend(email);
            try {
                invite(friend, true);
            } catch (final IOException e) {
                return;
            }
            if (subscribe) {
                try {
                    //if they have requested a subscription to us, we'll accept it.
                    this.xmppHandler.subscribed(email);
        
                    // We also automatically subscribe to them in turn so we 
                    // know about their presence.
                    this.xmppHandler.subscribe(email);
                    return;
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
        sync(friend, Status.friend);
    }

    private void sync(final Friend friend, final Status status) {
        final Friends friends = model.getFriends();
        friend.setStatus(status);
        friends.setNeedsSync(true);
        Events.asyncEventBus().post(new FriendStatusChangedEvent(friend));
        Events.sync(SyncPath.FRIENDS, friends.getFriends());
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
                
                final Friend friend = modelUtils.makeFriend(email.trim());
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
