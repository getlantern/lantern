package org.lantern.ui;

import org.eclipse.swt.SWT;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.Shell;
import org.lantern.LanternUtils;

public class NotificationDialog {

    Shell shell;
    public NotificationDialog(final NotificationManager manager) {
        if (LanternUtils.isTesting()) {
            return;
        }
        final Display display = Display.getDefault();

        display.syncExec(new Runnable() {
            @Override
            public void run() {
                shell = new Shell(Display.getDefault().getActiveShell(), SWT.NO_FOCUS | SWT.NO_TRIM | SWT.ON_TOP);
                shell.addListener(SWT.Dispose, new Listener() {
                    @Override
                    public void handleEvent(Event event) {
                        manager.remove(NotificationDialog.this);
                    }
                });
            }
        });
    }

}
