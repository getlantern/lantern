package org.lantern;

import org.junit.Test;
import org.lantern.state.Settings;
import org.lantern.ui.NotificationDialog;
import org.lantern.ui.NotificationManager;

public class NotificationDialogTest {

    @Test
    public void test() {
        final Settings settings = new Settings();
        final NotificationManager nm = new NotificationManager(settings);
        final NotificationDialog dialog = new NotificationDialog(nm);
        
        try {
            Thread.sleep(10000);
        } catch (InterruptedException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
    }

}
