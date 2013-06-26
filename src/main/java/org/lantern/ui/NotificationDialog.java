package org.lantern.ui;

import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;

import javax.swing.JDialog;
import javax.swing.JWindow;

import org.lantern.LanternUtils;

public class NotificationDialog {

    public static final int ALPHA = 240;
    public static final int WIDTH = 320;
    public static final int HEIGHT = 120;

    JWindow dialog;

    public NotificationDialog(final NotificationManager manager) {
        if (LanternUtils.isTesting()) {
            return;
        }
        JDialog child = new JDialog();
        dialog = new JWindow(child);
        dialog.addWindowListener(new WindowAdapter() {

            @Override
            public void windowClosed(WindowEvent arg0) {
                manager.remove(NotificationDialog.this);
            }
        });
        dialog.setAlwaysOnTop(true);
        child.setUndecorated(true);
        dialog.setFocusable(false);
    }

}
