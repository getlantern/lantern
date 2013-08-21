package org.lantern.state;

import java.util.ArrayList;

import org.lantern.XmppHandler;
import org.lantern.event.Events;
import org.lastbamboo.common.p2p.P2PConnectionEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;

public class InviteQueue {
    private static final Logger log = LoggerFactory
            .getLogger(InviteQueue.class);

    private final XmppHandler xmppHandler;
    private final Model model;

    @Inject
    public InviteQueue(final XmppHandler handler, final Model model) {
        this.xmppHandler = handler;
        this.model = model;
        Events.register(this);
    }

    @Subscribe
    public void onP2PConnectionEvent(P2PConnectionEvent e) {
        if (e.isConnected()) {
            // resend invites
            Friends friends = model.getFriends();
            ArrayList<String> pendingInvites = new ArrayList<String>(
                    model.getPendingInvites());
            for (String email : pendingInvites) {
                log.info("Resending pending invite to {}", email);
                Friend friend = friends.get(email);
                xmppHandler.sendInvite(friend, true);
            }
        }

    }

    public void invite(Friend friend) {
        String email = friend.getEmail();
        try {
            if (xmppHandler.sendInvite(friend, false)) {
                // we need to mark this email as pending, in case
                // our invite gets lost.
                model.addPendingInvite(email);
            }
        } catch (Exception e) {
            log.debug("failed to send invite: ", e);
            model.addPendingInvite(email);
        }
        Events.sync(SyncPath.FRIENDS, model.getFriends().getFriends());

    }

}
