package org.lantern;

import org.lantern.event.Events;
import org.lantern.event.FriendStatusChangedEvent;
import org.lantern.state.Friend;
import org.lantern.state.Friend.Status;
import org.lantern.state.Friends;
import org.lantern.state.InviteQueue;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;
import org.lantern.state.Notification.MessageType;
import org.lantern.state.SyncPath;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

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
    private final InviteQueue inviteQueue;

    @Inject
    public DefaultFriender(final Model model, final XmppHandler xmppHandler,
        final ModelUtils modelUtils, final InviteQueue inviteQueue) {
        this.model = model;
        this.xmppHandler = xmppHandler;
        this.modelUtils = modelUtils;
        this.inviteQueue = inviteQueue;
    }

    @Override
    public void removeFriend(final String json) {
        final String email = JsonUtils.getValueFromJson("email", json).toLowerCase();
        setFriendStatus(email, Status.rejected);
        
        this.xmppHandler.unsubscribe(email);
        this.xmppHandler.unsubscribed(email);
    }

    @Override
    public void addFriend(String json) {
        final String email = JsonUtils.getValueFromJson("email", json).toLowerCase();
        addFriendByEmail(email);
    }

    private void addFriendByEmail(final String email) {
        setFriendStatus(email, Status.friend);
        
        try {
            //if they have requested a subscription to us, we'll accept it.
            this.xmppHandler.subscribed(email);

            // We also automatically subscribe to them in turn so we know about
            // their presence.
            this.xmppHandler.subscribe(email);
        } catch (final IllegalStateException e) {
            log.error("IllegalStateException while friending (you are probably offline)", e);
            return;
        }
    }

    private void setFriendStatus(final String email, final Status status) {
        final Friends friends = model.getFriends();
        Friend friend = friends.get(email);
        if (friend != null && friend.getStatus() == Status.friend) {
            log.debug("Already friends with {}", email);
            model.addNotification("You have already friended "+email+".",
              MessageType.info, 30);
            Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
            return;
        }
        if (friend == null || friend.getStatus() == Status.rejected) {
            friend = modelUtils.makeFriend(email);
            if (status == Status.friend) {
                model.addNotification("An email will be sent to "+email+" "+
                    "with a notification that you friended them. "+
                    "If they do not yet have a Lantern invite, they will "+
                    "be invited when the network can accommodate them.",
                    MessageType.info, 30);
                Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
                inviteQueue.invite(friend);
            }
        }
        friend.setStatus(status);
        friends.setNeedsSync(true);
        Events.asyncEventBus().post(new FriendStatusChangedEvent(friend));
        Events.sync(SyncPath.FRIENDS, friends.getFriends());
    }
}
