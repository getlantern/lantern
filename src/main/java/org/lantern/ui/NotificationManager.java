package org.lantern.ui;

import java.awt.GraphicsConfiguration;
import java.awt.GraphicsDevice;
import java.awt.GraphicsEnvironment;
import java.awt.Insets;
import java.awt.Point;
import java.awt.Rectangle;
import java.awt.Toolkit;
import java.util.ArrayList;
import java.util.List;

import org.lantern.state.Settings;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class NotificationManager {

    List<NotificationDialog> notifications = new ArrayList<NotificationDialog>();
    private final Settings settings;
    public static final int MAX_NOTIFICATIONS = 3;

    @Inject
    public NotificationManager(Settings settings) {
        this.settings = settings;
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

        doNotify(notification);

    }
    /*
    static public Rectangle getScreenBounds(Window wnd) {
        Rectangle sb;
        Insets si = getScreenInsets(wnd);

        if (wnd == null) {
            sb = Toolkit.getDefaultToolkit().getGraphicsConfiguration().getBounds();
        } else {
            sb = wnd.getGraphicsConfiguration().getBounds();
        }

        sb.x += si.left;
        sb.width -= (si.left + si.right);
        sb.y += si.top;
        sb.height -= (si.top + si.bottom);
        return sb;
    }

    static public Insets getScreenInsets(Window wnd) {
        Insets si;

        if (wnd == null) {
            si = Toolkit.getDefaultToolkit().getScreenInsets(new Frame().getGraphicsConfiguration());
        } else {
            si = wnd.getToolkit().getScreenInsets(wnd.getGraphicsConfiguration());
        }
        return si;
    }
    */
    protected synchronized void doNotify(NotificationDialog notification) {
        //install the dialog in the shell

        Rectangle clientArea = getClientArea();

        int startX = clientArea.x + clientArea.width - notification.dialog.getSize().width;

        int totalHeight = 0;
        for (NotificationDialog existing : notifications) {
            totalHeight += existing.dialog.getSize().height;
        }

        totalHeight += notification.dialog.getSize().height;

        int startY = clientArea.y + clientArea.height - totalHeight;

        if (startY < 0) {
            //no need to notify
            return;
        }

        notification.dialog.setLocation(startX, startY);
        notification.dialog.setVisible(true);

        notifications.add(notification);

    }

    private Rectangle getClientArea() {

        GraphicsDevice gd = GraphicsEnvironment.getLocalGraphicsEnvironment().getDefaultScreenDevice();

        GraphicsConfiguration gc = gd.getDefaultConfiguration();
        Rectangle bounds = gc.getBounds();

        Insets screenInsets = Toolkit.getDefaultToolkit().getScreenInsets(gc);

        Rectangle clientArea = new Rectangle();

        clientArea.x = bounds.x + screenInsets.left;
        clientArea.y = bounds.y + screenInsets.top;
        clientArea.height = bounds.height - screenInsets.top
                - screenInsets.bottom;
        clientArea.width = bounds.width - screenInsets.left
                - screenInsets.right;

        return clientArea;
    }

    public void remove(NotificationDialog toRemove) {
        boolean later = false;
        for (int i = 0; i < notifications.size(); ++i) {
            NotificationDialog notification = notifications.get(i);
            if (later) {
                Point location = notification.dialog.getLocation();
                int height = notification.dialog.getSize().height;
                notification.dialog.setLocation(location.x, location.y + height);
            } else if (notification == toRemove) {
                later = true;
            }
        }
        notifications.remove(toRemove);
    }
}
