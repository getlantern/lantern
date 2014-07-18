package org.lantern.ui;

import static javax.swing.JOptionPane.INFORMATION_MESSAGE;
import static javax.swing.JOptionPane.OK_OPTION;
import static javax.swing.JOptionPane.YES_OPTION;
import static javax.swing.JOptionPane.showMessageDialog;

import java.util.concurrent.atomic.AtomicBoolean;

import javax.swing.JCheckBox;
import javax.swing.JOptionPane;
import javax.swing.SwingUtilities;

import org.lantern.MessageKey;
import org.lantern.MessageService;
import org.lantern.Tr;
import org.lantern.event.Events;
import org.lantern.event.MessageEvent;
import org.lantern.state.Model;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class SwingMessageService implements MessageService {

    private final Model model;

    @Inject
    public SwingMessageService(final Model model) {
        this.model = model;
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
    public void showMessage(final String title, final String message) {
        if (SwingUtilities.isEventDispatchThread()) {
            doShowMessage(title, message);
        } else {
            try {
                SwingUtilities.invokeAndWait(new Runnable() {
                    @Override
                    public void run() {
                        doShowMessage(title, message);
                    }
                });
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }
    }

    private void doShowMessage(String title, String message) {
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
    public boolean askQuestion(final String title, final String message) {
        if (SwingUtilities.isEventDispatchThread()) {
            return doAskQuestion(title, message);
        } else {
            final AtomicBoolean result = new AtomicBoolean();
            try {
                SwingUtilities.invokeAndWait(new Runnable() {
                    @Override
                    public void run() {
                        result.set(doAskQuestion(title, message));
                    }
                });
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
            return result.get();
        }
    }

    private boolean doAskQuestion(final String title, final String message) {
        final String key = title + message;
        if (!this.model.shouldShowDialog(key)) {
            return false;
        }
        
        final JCheckBox cb = new JCheckBox(Tr.tr(MessageKey.DO_NOT_SHOW));
        final String html = 
                "<html><body><p style='width: 200px;'>"+message+"</body></html>";
        final Object[] params = {html, cb};
        final int response = 
                JOptionPane.showConfirmDialog(null, params, title, 
                        JOptionPane.YES_NO_OPTION);
        final boolean dontShow = cb.isSelected();
        if (dontShow) {
            this.model.doNotShowDialog(key);
        }
        return response == YES_OPTION;
    }

    @Override
    @Subscribe
    public void onMessageEvent(MessageEvent me) {
        showMessage(me.getTitle(), me.getMsg());
    }

}
