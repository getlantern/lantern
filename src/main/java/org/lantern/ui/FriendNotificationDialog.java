package org.lantern.ui;

import org.apache.commons.lang3.StringUtils;
import org.eclipse.swt.SWT;
import org.eclipse.swt.events.SelectionEvent;
import org.eclipse.swt.events.SelectionListener;
import org.eclipse.swt.layout.RowData;
import org.eclipse.swt.layout.RowLayout;
import org.eclipse.swt.widgets.Button;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Label;
import org.lantern.LanternUtils;
import org.lantern.event.Events;
import org.lantern.state.Friend;
import org.lantern.state.Friend.Status;
import org.lantern.state.Friends;
import org.lantern.state.SyncPath;

public class FriendNotificationDialog extends NotificationDialog {

    private final Friends friends;
    private final Friend friend;

    public FriendNotificationDialog(NotificationManager manager, Friends friends, Friend friend) {
        super(manager);
        this.friends = friends;
        this.friend = friend;
        layout();
    }

    protected void layout() {
        if (LanternUtils.isTesting()) {
            return;
        }
        final Display display = Display.getDefault();

        display.syncExec(new Runnable() {
            @Override
            public void run() {
                doLayout();
            }
        });
    }

    protected void doLayout() {
        // accept/decline/ask again later

        shell.setSize(NotificationDialog.WIDTH, NotificationDialog.HEIGHT);
        shell.setAlpha(NotificationDialog.ALPHA);

        final RowLayout layout = new RowLayout(SWT.VERTICAL);
        layout.marginHeight = 10;
        layout.marginWidth = 10;
        shell.setLayout(layout);

        final int innerWidth = NotificationDialog.WIDTH - layout.marginWidth * 2 - layout.spacing * 2;

        final Label titleLabel = new Label(shell, SWT.WRAP);
        final RowData data = new RowData();
        data.width = innerWidth;
        titleLabel.setLayoutData(data);

        final String name = friend.getName();
        final String email = friend.getEmail();
        final String text = "%s is running Lantern.  Do you want to add %s as your Lantern friend?";
        final String displayName;
        final String displayEmail;
        if (StringUtils.isEmpty(name)) {
            displayName = email;
            displayEmail = email;
        } else {
            displayName = name;
            displayEmail = name + " <" + email + ">";
        }
        final String label = String.format(text, displayEmail, displayName);
        titleLabel.setText(label);

        final Composite buttons = new Composite(shell, 0);
        buttons.setSize(innerWidth, 50);
        final RowLayout layout2 = new RowLayout(SWT.HORIZONTAL);
        layout2.center = true;
        layout2.justify = true;
        buttons.setLayout(layout2);

        final Button yesButton = new Button(buttons, SWT.NONE);
        yesButton.setText("Yes");
        yesButton.addSelectionListener(new SelectionListener() {
            @Override
            public void widgetSelected(SelectionEvent e) {
                yes();
            }

            @Override
            public void widgetDefaultSelected(SelectionEvent e) {
                yes();
            }
        });
        final Button noButton = new Button(buttons, SWT.NONE);
        noButton.setText("No");
        noButton.addSelectionListener(new SelectionListener() {
            @Override
            public void widgetSelected(SelectionEvent e) {
                no();
            }

            @Override
            public void widgetDefaultSelected(SelectionEvent e) {
                no();
            }
        });

        final Button laterButton = new Button(buttons, SWT.NONE);
        laterButton.setText("Ask again tomorrow");
        laterButton.addSelectionListener(new SelectionListener() {
            @Override
            public void widgetSelected(SelectionEvent e) {
                later();
            }

            @Override
            public void widgetDefaultSelected(SelectionEvent e) {
                later();
            }
        });
        shell.pack();
    }

    protected void later() {
        long tomorrow = System.currentTimeMillis() + 1000 * 86400;
        friend.setNextQuery(tomorrow);
        friend.setStatus(Status.pending);
        friends.add(friend);
        friends.setNeedsSync(true);
        Events.sync(SyncPath.FRIENDS, friends.getFriends());
        shell.dispose();
    }

    protected void no() {
        setFriendStatus(Status.rejected);
    }

    protected void yes() {
        setFriendStatus(Status.friend);
    }

    private void setFriendStatus(Status status) {
        friend.setStatus(status);
        friends.add(friend);
        friends.setNeedsSync(true);
        Events.sync(SyncPath.FRIENDS, friends.getFriends());
        shell.dispose();
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
}
