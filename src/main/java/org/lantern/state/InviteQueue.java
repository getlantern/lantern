package org.lantern.state;

import java.util.ArrayList;

import org.lantern.Roster;
import org.lantern.XmppHandler;
import org.lantern.event.Events;
import org.lastbamboo.common.p2p.P2PConnectionEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;

public class InviteQueue {
    private static final Logger LOG = LoggerFactory
            .getLogger(InviteQueue.class);

    private final XmppHandler xmppHandler;
    private final Model model;

    private final Roster roster;

    @Inject
    public InviteQueue(final XmppHandler handler, final Model model,
            final Roster roster) {
        this.xmppHandler = handler;
        this.model = model;
        this.roster = roster;
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
                LOG.info("Resending pending invite to {}", email);
                Friend friend = friends.get(email);
                xmppHandler.sendInvite(friend, true);
            }
        }

    }

    public void invite(Friend friend) {
        String email = friend.getEmail();
        if (xmppHandler.sendInvite(friend, false)) {
            // we need to mark this email as pending, in case
            // our invite gets lost.
            model.addPendingInvite(email);
        }

        Events.sync(SyncPath.FRIENDS, model.getFriends().getFriends());

    }

}
