package org.lantern.ui;

import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;

import javax.swing.JDialog;
import javax.swing.JWindow;

import org.lantern.LanternUtils;

public class NotificationDialog {

    public static final int ALPHA = 240;
    public static final int WIDTH = 320;
    public static final int HEIGHT = 320;

    protected JWindow window;

    public NotificationDialog(final NotificationManager manager) {
        if (LanternUtils.isTesting()) {
            return;
        }
        JDialog child = new JDialog();
        window = new JWindow(child);
        window.addWindowListener(new WindowAdapter() {

            @Override
            public void windowClosed(WindowEvent arg0) {
                manager.remove(NotificationDialog.this);
            }
        });
        window.setAlwaysOnTop(true);
        child.setUndecorated(true);
        window.setFocusable(false);
    }
    
    public void dispose() {
        window.dispose();
    }

}
