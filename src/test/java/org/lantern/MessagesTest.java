package org.lantern;

import static org.junit.Assert.assertEquals;

import org.junit.Test;
import org.lantern.state.Model;
import org.lantern.state.Notification;

public class MessagesTest {

    @Test
    public void testMessages() throws Exception {
        final Model model = new Model();
        final Messages msgs = new Messages(model);
        assertEquals(0, model.getNotifications().size());
        final String email = "test@test.org";
        msgs.info(MessageKey.ALREADY_ADDED, email);
        
        int tries = 0;
        while (tries < 30) {
            if (model.getNotifications().size() > 0) {
                break;
            }
            Thread.sleep(50);
            tries++;
        }
        assertEquals(1, model.getNotifications().size());
        final Notification note = model.getNotifications().get(new Integer(0));
        
        assertEquals("You have already added test@test.org.", note.getMessage());
    }
}
