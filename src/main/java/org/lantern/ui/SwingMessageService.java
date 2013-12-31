package org.lantern.ui;

import static javax.swing.JOptionPane.*;

import org.lantern.MessageService;
import org.lantern.event.Events;
import org.lantern.event.MessageEvent;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Singleton;

@Singleton
public class SwingMessageService implements MessageService {

    public SwingMessageService() {
        Events.register(this);
    }

    /**
     * Shows a message to the user using a dialog box;
     * 
     * @param title
     *            The title of the dialog box.
     * @param msg
     *            The message.
     */
    @Override
    public void showMessage(String title, String message) {
        showMessageDialog(null, message, title, INFORMATION_MESSAGE | OK_OPTION);
    }

    /**
     * Shows a dialog to the user asking a yes or no question.
     * 
     * @param title
     *            The title for the dialog.
     * @param question
     *            The question to ask.
     * @return <code>true</code> if the user answered yes, otherwise
     *         <code>false</code>
     */
    @Override
    public boolean askQuestion(String title, String message) {
        return showOptionDialog(null,
                message,
                title,
                YES_NO_OPTION,
                INFORMATION_MESSAGE,
                null,
                null,
                null) == YES_OPTION;
    }

    @Override
    @Subscribe
    public void onMessageEvent(MessageEvent me) {
        showMessage(me.getTitle(), me.getMsg());
    }

}
