package org.lantern.ui;

import java.util.concurrent.atomic.AtomicInteger;

import org.eclipse.swt.SWT;
import org.eclipse.swt.widgets.MessageBox;
import org.eclipse.swt.widgets.Shell;
import org.lantern.DisplayWrapper;
import org.lantern.MessageService;
import org.lantern.event.MessageEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

public class SwtMessageService implements MessageService {
    
    private final Logger log = LoggerFactory.getLogger(getClass());

    private static final int DEFAULT_QUESTION_FLAGS = 
        SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
    
    /**
     * Shows a message to the user using a dialog box;
     * 
     * @param title The title of the dialog box.
     * @param msg The message.
     */
    @Override
    public void showMessage(final String title, final String msg) {
        final int flags = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.OK;
        askQuestion(title, msg, flags);
    }
    
    /**
     * Shows a dialog to the user asking a yes or no question.
     * 
     * @param title The title for the dialog.
     * @param question The question to ask.
     * @return <code>true</code> if the user answered yes, otherwise
     * <code>false</code>
     */
    public boolean askQuestion(final String title, final String question) {
        return askQuestion(title, question, DEFAULT_QUESTION_FLAGS) == SWT.YES;
    }
    
    @Override
    public int askQuestion(final String title, final String question, 
        final int style) {
        final AtomicInteger response = new AtomicInteger();
        DisplayWrapper.getDisplay().syncExec(new Runnable() {
            @Override
            public void run() {
                response.set(askQuestionOnThread(title, question, style));
            }
        });
        log.info("Returned from sync exec");
        return response.get();
    }
    
    private int askQuestionOnThread(final String title, 
        final String question, final int style) {
        log.info("Creating display...");
        final Shell boxShell = new Shell(DisplayWrapper.getDisplay());
        log.info("Created display...");
        final MessageBox messageBox = new MessageBox (boxShell, style);
        messageBox.setText(title);
        messageBox.setMessage(question);
        final int result = messageBox.open();
        boxShell.dispose();
        return result;
    }

    @Override
    @Subscribe
    public void onMessageEvent(final MessageEvent me) {
        showMessage(me.getTitle(), me.getMsg());
    }
}
