package org.lantern.ui;

import java.awt.Color;
import java.awt.Dimension;

import javax.swing.BorderFactory;
import javax.swing.JEditorPane;
import javax.swing.ToolTipManager;
import javax.swing.event.HyperlinkEvent;
import javax.swing.event.HyperlinkListener;

import org.apache.commons.lang3.StringUtils;
import org.lantern.LanternUtils;
import org.lantern.event.Events;
import org.lantern.event.FriendStatusChangedEvent;
import org.lantern.state.Friend;
import org.lantern.state.Friend.Status;
import org.lantern.state.Friends;
import org.lantern.state.SyncPath;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

public class FriendNotificationDialog extends NotificationDialog {
    private final Logger log =
        LoggerFactory.getLogger(LanternUtils.class);

    private final Friends friends;
    private final Friend friend;

    public FriendNotificationDialog(NotificationManager manager,
            Friends friends, Friend friend) {
        super(manager);
        this.friends = friends;
        this.friend = friend;
        Events.register(this);
        layout();
    }

    protected void layout() {
        if (LanternUtils.isTesting()) {
            return;
        }
        doLayout();
    }

    protected void doLayout() {
        final String name = friend.getName();
        final String email = friend.getEmail();
        final String text = "<html><div style=\"width:%dpx; padding: 5px;\">"
                + "%s is running Lantern.  Do you want to add %s as your Lantern friend?<br>"
                + "<a href=\"yes\">Trust</a> &nbsp;&nbsp;<a href=\"no\">Don't trust</a>&nbsp;&nbsp; <a href=\"later\">Ask again tomorrow</a>"
                + "</div></html>";
        final String displayName;
        final String displayEmail;
        if (StringUtils.isEmpty(name)) {
            displayName = email;
            displayEmail = email;
        } else {
            displayName = name;
            displayEmail = name + " &lt;" + email + "&gt;";
        }
        final String popupHtml = String.format(text, WIDTH, displayEmail,
                displayName);

        dialog.setMaximumSize(new Dimension(WIDTH, HEIGHT));
        dialog.setBackground(new Color(255, 255, 255, ALPHA));
        final JEditorPane pane = new JEditorPane("text/html", popupHtml);
        pane.setEditable(false);
        pane.setBorder(BorderFactory.createLineBorder(Color.black));
        ToolTipManager.sharedInstance().registerComponent(pane);

        HyperlinkListener l = new HyperlinkListener() {
            @Override
            public void hyperlinkUpdate(HyperlinkEvent e) {
                if (HyperlinkEvent.EventType.ACTIVATED == e.getEventType()) {
                    String url = e.getDescription().toString();
                    if (url.equals("yes")) {
                        yes();
                    } else if (url.equals("no")) {
                        no();
                    } else if (url.equals("later")) {
                        later();
                    } else {
                        log.debug("Unexpected URL ");
                    }
                }

            }

        };
        pane.addHyperlinkListener(l);
        dialog.add(pane);
        dialog.pack();
    }

    protected void later() {
        long tomorrow = System.currentTimeMillis() + 1000 * 86400;
        friend.setNextQuery(tomorrow);
        friend.setStatus(Status.pending);
        Events.asyncEventBus().post(new FriendStatusChangedEvent(friend));
        friends.add(friend);
        friends.setNeedsSync(true);
        Events.sync(SyncPath.FRIENDS, friends.getFriends());
        dialog.dispose();
    }

    protected void no() {
        setFriendStatus(Status.rejected);
    }

    protected void yes() {
        setFriendStatus(Status.friend);
    }

    private void setFriendStatus(Status status) {
        friend.setStatus(status);
        Events.asyncEventBus().post(new FriendStatusChangedEvent(friend));
        friends.add(friend);
        friends.setNeedsSync(true);
        Events.sync(SyncPath.FRIENDS, friends.getFriends());
        dialog.dispose();
    }

    @Override
    public boolean equals(Object other) {
        if (other == null) {
            return false;
        }
        if (!(other instanceof FriendNotificationDialog)) {
            return false;
        }
        FriendNotificationDialog o = (FriendNotificationDialog) other;
        return o.friend.getEmail().equals(friend.getEmail());
    }

    @Subscribe
    public void onFriendStatusChanged(FriendStatusChangedEvent e) {
        if (e.getFriend() == friend) {
            dialog.dispose();
        }
    }
}
