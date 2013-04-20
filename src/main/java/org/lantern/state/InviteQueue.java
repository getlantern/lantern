package org.lantern.state;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.lang3.StringUtils;
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

        int n = emails.size();
        String msg = n > 1 ? "Invitations have" : "An invitation has";
        LanternRosterEntry entry0 = entries.get(0);
        final String name0;
        if (entry0 == null) {
            name0 = emails.get(0);
        } else {
            name0 = entry0.getName();
        }
        msg += " been queued for <span class=\"titled\" title=\"" + name0 + "\">" + emails.get(0) + "</span>";
        if (n > 2) {
          msg += " and <span class=\"titled\" title=\""+StringUtils.join(emails, ", ")+"\">"+(n-1)+" others</span>.";
        } else if (n == 2) {
            LanternRosterEntry entry1 = entries.get(1);
            final String name1;
            if (entry1 == null) {
                name1 = emails.get(1);
            } else {
                name1 = entry1.getName();
            }
          msg += " and <span class=\"titled\" title=\"" + name1 + "\">"+emails.get(1)+"</span>.";
        } else {
          msg += ".";
        }
        model.addNotification(msg, MessageType.info, 30);
        Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
    }

}
