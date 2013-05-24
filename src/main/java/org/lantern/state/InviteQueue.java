package org.lantern.state;

import java.util.ArrayList;
import java.util.List;

import org.lantern.LanternRosterEntry;
import org.lantern.Roster;
import org.lantern.XmppHandler;
import org.lantern.event.Events;
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
            ArrayList<String> pendingInvites = new ArrayList<String>(
                    model.getPendingInvites());
            for (String email : pendingInvites) {
                LOG.info("Resending pending invite to {}", email);
                xmppHandler.sendInvite(email, true);
            }
        }

    }

    public void invite(List<String> emails) {
        // XXX i18n
        ArrayList<LanternRosterEntry> entries = new ArrayList<LanternRosterEntry>();
        for (String email : emails) {
            if (xmppHandler.sendInvite(email, false)) {
                entries.add(roster.getRosterEntry(email));
                //we also need to mark this email as pending, in case
                //our invite gets lost.
                model.addPendingInvite(email);
            } else {
                entries.add(null);
            }
        }

        final String msg = "Request processing. After accepting your request, "+
            "new Lantern Friends appear on your map once you connect to "+
            "them successfully.";
        // XXX not entirely true until we fix
        //     https://github.com/getlantern/lantern/issues/647
        // XXX change message to say "look out for a notification" once we fix
        //     https://github.com/getlantern/lantern/issues/782
        model.addNotification(msg, MessageType.info, 30);
        Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());

        int newInvites = model.getNinvites() - emails.size();
        if (newInvites == 0) {
            // setting Ninvites to 0 triggers a notification, but we're not
            // really sure that all of these invitations will actually be
            // charged to the user (this depends on lantern-controller),
            // so we don't want to trigger that until we're sure.  Setting
            // nInvites to -1 tells the front-end that we have no idea how
            // many invites we have

            model.setNinvites(-1);
        } else {
            model.setNinvites(newInvites);
        }
        Events.sync(SyncPath.NINVITES, model.getNinvites());
    }

}
