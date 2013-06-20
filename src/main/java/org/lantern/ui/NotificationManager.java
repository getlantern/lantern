package org.lantern.ui;

import java.util.ArrayList;
import java.util.List;

import org.eclipse.swt.SWT;
import org.eclipse.swt.graphics.Color;
import org.eclipse.swt.graphics.Point;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.layout.FillLayout;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Monitor;
import org.eclipse.swt.widgets.Shell;
import org.lantern.state.Settings;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class NotificationManager {

    List<NotificationDialog> notifications = new ArrayList<NotificationDialog>();
    private Shell shell;
    private final Settings settings;
    public static final int MAX_NOTIFICATIONS = 3;

    @Inject
    public NotificationManager(Settings settings) {
        this.settings = settings;
    }

    private void initShell(final Display display) {
        if (shell != null) {
            //shell already initialized
            return;
        }
        shell = new Shell(Display.getDefault().getActiveShell(), SWT.NO_FOCUS
                | SWT.NO_TRIM);

        shell.setLayout(new FillLayout(SWT.VERTICAL));

        Color backgroundColor = new Color(display, 255, 251, 204);

        shell.setBackground(backgroundColor);
    }

    public synchronized void notify(final NotificationDialog notification) {
        if (!settings.isUiEnabled()) {
            //no UI, no notifications
            return;
        }
        if (notifications.size() > MAX_NOTIFICATIONS ) {
            return;
        }

        for (NotificationDialog dialog : notifications) {
            if (dialog.equals(notification)) {
                //already have a dialog for this friend
                return;
            }
        }
        final Display display = Display.getDefault();

        display.asyncExec(new Runnable() {
            @Override
            public void run() {
                initShell(display);
                doNotify(notification);
            }
        });

    }

    protected synchronized void doNotify(NotificationDialog notification) {
        //install the dialog in the shell

        Display display = Display.getDefault();

        Monitor monitor = display.getPrimaryMonitor();
        Rectangle clientArea = monitor.getClientArea();

        int startX = clientArea.x + clientArea.width - 300;
        int startY = clientArea.y + clientArea.height - (100 * (notifications.size() + 1));

        if (startY < 0) {
            //no need to notify
            return;
        }

        notification.shell.setLocation(startX, startY);
        notification.shell.setVisible(true);

        notifications.add(notification);

    }

    public void remove(NotificationDialog toRemove) {
        boolean later = false;
        for (int i = 0; i < notifications.size(); ++i) {
            NotificationDialog notification = notifications.get(i);
            if (later) {
                Point location = notification.shell.getLocation();
                int height = notification.shell.getSize().y;
                notification.shell.setLocation(location.x, location.y + height);
            } else if (notification == toRemove) {
                later = true;
            }
        }
        notifications.remove(toRemove);
    }
}
