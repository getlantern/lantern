package org.lantern.state;

import java.util.ArrayList;
import java.util.List;

import org.lantern.LanternRosterEntry;
import org.lantern.Roster;
import org.lantern.XmppHandler;
import org.lantern.event.Events;
import org.lantern.state.Friend.Status;
import org.lantern.state.Notification.MessageType;
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

    public void invite(List<String> emails) {
        // XXX i18n
        ArrayList<LanternRosterEntry> entries = new ArrayList<LanternRosterEntry>();
        for (String email : emails) {
            //also, newly-invited users become friends
            Friend friend = new Friend(email);
            friend.setStatus(Status.friend);
            model.getFriends().add(friend);

            if (xmppHandler.sendInvite(friend, false)) {
                entries.add(roster.getRosterEntry(email));
                //we also need to mark this email as pending, in case
                //our invite gets lost.
                model.addPendingInvite(email);

            } else {
                entries.add(null);
            }
        }

        Events.sync(SyncPath.FRIENDS, model.getFriends().getFriends());

        final String msg = "Request processing. After accepting your request, "+
            "new Lantern Friends appear on your map once you connect to "+
            "them successfully.";
        // XXX not entirely true until we fix
        //     https://github.com/getlantern/lantern/issues/647
        // XXX change message to say "look out for a notification" once we fix
        //     https://github.com/getlantern/lantern/issues/782
        model.addNotification(msg, MessageType.info, 30);
        Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
    }

}
