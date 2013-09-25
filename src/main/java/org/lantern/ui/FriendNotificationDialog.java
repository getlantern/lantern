package org.lantern.ui;

import java.awt.Color;
import java.io.IOException;
import java.io.InputStream;

import javax.swing.BorderFactory;
import javax.swing.JEditorPane;
import javax.swing.ToolTipManager;
import javax.swing.event.HyperlinkEvent;
import javax.swing.event.HyperlinkListener;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.lantern.LanternUtils;
import org.lantern.event.Events;
import org.lantern.event.FriendStatusChangedEvent;
import org.lantern.state.ClientFriend;
import org.lantern.state.Friend.Status;
import org.lantern.state.FriendsHandler;
import org.lantern.state.StaticSettings;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

/**
 * Dialog for asking the user whether or not they want to friend another user
 * we've seen on the network.
 */
public class FriendNotificationDialog extends NotificationDialog {
    private final Logger log =
        LoggerFactory.getLogger(LanternUtils.class);

    private final FriendsHandler friendsHandler;
    private final ClientFriend friend;

    private final String name;

    private final String email;

    public FriendNotificationDialog(NotificationManager manager,
            FriendsHandler friends, final ClientFriend friend) {
        super(manager);
        this.friendsHandler = friends;
        this.friend = friend;
        this.name = friend.getName();
        this.email = friend.getEmail();
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
        final String text = loadText();
        final String displayEmail;
        if (StringUtils.isEmpty(name)) {
            displayEmail = email;
        } else {
            displayEmail = name + " (" + email + ")";
        }

        final String cssurl = StaticSettings.getLocalEndpoint() + "/_css/app.css"; 
        final String iconurl = StaticSettings.getLocalEndpoint() + "/img/favicon.png";
        final String popupHtml = String.format(text, cssurl, iconurl, displayEmail);

        dialog.setBackground(new Color(200, 200, 200, ALPHA));
        final JEditorPane pane = new JEditorPane("text/html", popupHtml);
        pane.setEditable(false);
        pane.setBorder(BorderFactory.createLineBorder(Color.black));
        ToolTipManager.sharedInstance().registerComponent(pane);

        HyperlinkListener l = new HyperlinkListener() {
            @Override
            public void hyperlinkUpdate(HyperlinkEvent e) {
                if (HyperlinkEvent.EventType.ACTIVATED == e.getEventType()) {
                    String url = e.getDescription().toString();
                    if (url.equals("friend")) {
                        yes();
                    } else if (url.equals("decline")) {
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
        //dialog.setVisible(true);
    }

    private String loadText() {
        InputStream is = null;
        try {
            is = getClass().getClassLoader().getResourceAsStream("friendsuggestion.html");
            return IOUtils.toString(is);
        } catch (IOException e) {
            throw new Error("Could not load friend suggestion?", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
    }

    protected void later() {
        final long tomorrow = System.currentTimeMillis() + 1000 * 86400;
        
        // Even though we don't store the following to disk, it's still used
        // in the logic for whether or not to ask the user again about a friend
        friend.setNextQuery(tomorrow);
        setFriendStatus(Status.pending);
    }

    protected void no() {
        setFriendStatus(Status.rejected);
    }

    protected void yes() {
        setFriendStatus(Status.friend);
    }

    private void setFriendStatus(final Status status) {
        dialog.dispose();
        
        // Can be null for testing.
        if (this.friendsHandler != null) {
            this.friendsHandler.setStatus(friend, status);
        }
        
        // This is necessary to sync up the user's interaction with the 
        // dialog with the state of the friend in the friends modal.
        Events.asyncEventBus().post(new FriendStatusChangedEvent(friend));
        friendsHandler.syncFriends();
    }

    @Subscribe
    public void onFriendStatusChanged(final FriendStatusChangedEvent e) {
        if (e.getFriend().getEmail().equals(friend.getEmail())) {
            dialog.dispose();
        }
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result + ((friend == null) ? 0 : friend.hashCode());
        return result;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj)
            return true;
        if (obj == null)
            return false;
        if (getClass() != obj.getClass())
            return false;
        FriendNotificationDialog other = (FriendNotificationDialog) obj;
        if (friend == null) {
            if (other.friend != null)
                return false;
        } else if (!friend.equals(other.friend))
            return false;
        return true;
    }
    
    /*
    public static void main(final String... args) {
        final NotificationManager manager = new NotificationManager(new Model().getSettings());
        final ClientFriend fr = new ClientFriend("tom.preston-werner@gmail.com");
        fr.setName("Tom Preston-Werner");
        final FriendNotificationDialog fnd = new FriendNotificationDialog(manager, null, fr);
        
    }
    */
}
