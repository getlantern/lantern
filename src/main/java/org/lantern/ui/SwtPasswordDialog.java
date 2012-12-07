package org.lantern.ui;

import java.awt.Point;
import java.util.concurrent.atomic.AtomicReference;

import org.apache.commons.lang.StringUtils;
import org.eclipse.swt.SWT;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.layout.RowData;
import org.eclipse.swt.layout.RowLayout;
import org.eclipse.swt.widgets.Button;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Dialog;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.widgets.Text;
import org.lantern.LanternUtils;
import org.lantern.privacy.UserInputRequiredException;

public class SwtPasswordDialog extends Dialog {

    private final String errorMessage;

    public SwtPasswordDialog() {
        this("");
    }

    public SwtPasswordDialog(final String errorMessage) {
        super(new Shell());
        this.errorMessage = errorMessage;
    }

    /**
     * Makes the dialog visible.
     * 
     * @return The password text.
     * @throws UserInputRequiredException If the user did not enter any input.
     */
    public String askForPassword() throws UserInputRequiredException {
        final Shell parent = getParent();
        final Shell shell = new Shell(parent, SWT.TITLE | SWT.BORDER
                | SWT.APPLICATION_MODAL);
        shell.setText("Lantern Password");

        final RowLayout layout = new RowLayout(SWT.VERTICAL);
        layout.marginLeft = 20;
        layout.marginTop = 20;
        layout.marginRight = 20;
        layout.marginBottom = 20;
        layout.center = true;
        
        shell.setLayout(layout);
        
        if (StringUtils.isNotBlank(errorMessage)) {
            final Composite errorComposite = newMarginComposite(shell, 2);
            final Label error = new Label(errorComposite, SWT.CENTER);
            error.setText(this.errorMessage);
            error.setForeground(parent.getDisplay().getSystemColor(SWT.COLOR_RED));
        }
        final Composite labelComposite = newMarginComposite(shell, 10);
        final Composite passwordComposite = newMarginComposite(shell, 10);
        final Composite buttonComposite = newMarginComposite(shell, 10);

        final Label description = new Label(labelComposite, SWT.CENTER);
        description.setText("Please enter your Lantern password.");
        
        final Text passwordField = 
            new Text(passwordComposite, SWT.SINGLE | SWT.BORDER | SWT.PASSWORD | SWT.CENTER);
        
        passwordField.setLayoutData(new RowData(200, 22));
        passwordField.setFocus();
        
        final Button buttonCancel = new Button(buttonComposite, SWT.PUSH);
        buttonCancel.setText("Cancel");
        
        final Button buttonOK = new Button(buttonComposite, SWT.PUSH);
        buttonOK.setText("OK");
        buttonOK.setEnabled(false);

        final AtomicReference<String> passwordText = 
            new AtomicReference<String>();
        
        passwordField.addListener(SWT.Modify, new Listener() {
            @Override
            public void handleEvent(final Event event) {
                 final String text = passwordField.getText();
                 if (StringUtils.isNotEmpty(text)) {
                     buttonOK.setEnabled(true);
                 } else {
                     buttonOK.setEnabled(false);
                 }
            }
        });

        buttonOK.addListener(SWT.Selection, new Listener() {
            @Override
            public void handleEvent(final Event event) {
                passwordText.set(passwordField.getText());
                shell.dispose();
            }
        });

        buttonCancel.addListener(SWT.Selection, new Listener() {
            @Override
            public void handleEvent(final Event event) {
                shell.dispose();
            }
        });
        
        shell.addListener(SWT.Traverse, new Listener() {
            @Override
            public void handleEvent(final Event event) {
                if (event.detail == SWT.TRAVERSE_ESCAPE) {
                    event.doit = false;
                }
            }
        });

        shell.pack();
        final Rectangle rect = shell.getBounds();
        final Point center = 
            LanternUtils.getScreenCenter(rect.width, rect.height);
        shell.setLocation((int)center.getX(), (int)center.getY());
        
        passwordField.setText("");
        
        shell.pack();
        shell.open();
        shell.forceActive();

        final Display display = parent.getDisplay();
        while (!shell.isDisposed()) {
            if (!display.readAndDispatch()) {
                display.sleep();
            }
        }

        final String text = passwordText.get();
        if (StringUtils.isEmpty(text)) {
            throw new UserInputRequiredException();
        }
        //shell.close();
        //shell.getDisplay().dispose();
        shell.dispose();
        display.dispose();
        return text;
    }

   private Composite newMarginComposite(final Shell shell, final int marginBottom) {
       final Composite comp = new Composite(shell, SWT.NONE);
       final RowLayout layout = new RowLayout();
       layout.marginBottom = marginBottom;
       layout.center = true;
       layout.pack = true;
       layout.type = SWT.HORIZONTAL;
       comp.setLayout(layout);
       return comp;
    }

    /*
    public static void main(String[] args) {
        final SwtPasswordDialog dialog = new SwtPasswordDialog("Big error");
        try {
            System.out.println(dialog.askForPassword());
        } catch (UserInputRequiredException e) {
            e.printStackTrace();
        }
    }
    */
}
