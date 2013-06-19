package org.lantern.ui;

import org.apache.commons.lang3.StringUtils;
import org.eclipse.swt.SWT;
import org.eclipse.swt.events.SelectionEvent;
import org.eclipse.swt.events.SelectionListener;
import org.eclipse.swt.layout.GridData;
import org.eclipse.swt.layout.GridLayout;
import org.eclipse.swt.widgets.Button;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Label;
import org.lantern.state.Friend;
import org.lantern.state.Friend.Status;
import org.lantern.state.Friends;

public class FriendNotificationDialog extends NotificationDialog {

    private final Friends friends;
    private final Friend friend;

    public FriendNotificationDialog(Friends friends, Friend friend) {
        super();
        this.friends = friends;
        this.friend = friend;
        init();
        layout();
    }

    protected void layout() {
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

        shell.setSize(300, 100);
        shell.setLayout(new GridLayout(3, false));

        Label titleLabel = new Label(shell, SWT.WRAP);
        GridData gd = new GridData(GridData.FILL_HORIZONTAL
                | GridData.VERTICAL_ALIGN_CENTER);
        gd.horizontalSpan = 3;
        titleLabel.setLayoutData(gd);

        final String name = friend.getName();
        final String email = friend.getEmail();
        final String text = "%s is running Lantern.  Do you want to be %s's friend?";
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

        Button yesButton = new Button(shell, SWT.NONE);
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
        Button noButton = new Button(shell, SWT.NONE);
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

        Button laterButton = new Button(shell, SWT.NONE);
        laterButton.setText("Later");
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
    }

    protected void later() {
        long tomorrow = System.currentTimeMillis() + 1000 * 86400;
        friend.setNextQuery(tomorrow);
        friend.setStatus(Status.requested);
        friends.add(friend);
        friends.setNeedsSync(true);
        shell.dispose();
    }

    protected void no() {
        friend.setStatus(Status.rejected);
        friends.add(friend);
        friends.setNeedsSync(true);
        shell.dispose();
    }

    protected void yes() {
        friend.setStatus(Status.friend);
        friends.add(friend);
        friends.setNeedsSync(true);
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
