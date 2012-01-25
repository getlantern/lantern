package org.lantern;

import java.io.File;
import java.util.concurrent.atomic.AtomicBoolean;

import org.eclipse.swt.SWT;
import org.eclipse.swt.browser.Browser;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.layout.FillLayout;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.MessageBox;
import org.eclipse.swt.widgets.Monitor;
import org.eclipse.swt.widgets.Shell;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Browser dashboard for controlling lantern.
 */
public class Dashboard {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    private Shell shell;

    /**
     * Opens the browser.
     */
    public void openBrowser() {
        LanternHub.display().syncExec(new Runnable() {
            @Override
            public void run() {
                buildBrowser();
            }
        });
    }
    
    protected void buildBrowser() {
        log.info("Creating shell...");
        if (this.shell != null && !this.shell.isDisposed()) {
            this.shell.forceActive();
            return;
        }
        this.shell = new Shell(LanternHub.display());
        final Image small = newImage("16on.png");
        final Image medium = newImage("32on.png");
        final Image large = newImage("64on.png");
        final Image[] icons = new Image[]{small, medium, large};
        shell.setImages(icons);
        // this.shell = createShell(this.display);
        shell.setText("Lantern Dashboard");
        //this.shell.setSize(720, 540);
        // shell.setFullScreen(true);

        final int minWidth = 970;
        final int minHeight = 630;

        log.debug("Centering on screen...");
        final Monitor primary = LanternHub.display().getPrimaryMonitor();
        final Rectangle bounds = primary.getBounds();
        final Rectangle rect = shell.getBounds();

        final int x = bounds.x + (bounds.width - rect.width) / 2;
        final int y = bounds.y + (bounds.height - rect.height) / 2;

        shell.setLocation(x, y);
        
        log.info("Creating new browser...");
        final Browser browser = new Browser(shell, SWT.NONE);
        browser.setSize(minWidth, minHeight);
        //browser.setBounds(0, 0, 800, 600);
        browser.setUrl("http://localhost:"+
            LanternHub.settings().getApiPort()+"/dashboard.html");
            
        shell.addListener (SWT.Close, new Listener () {
            @Override
            public void handleEvent(final Event event) {
                browser.stop();
                browser.setUrl("about:blank");
            }
        });
        shell.setLayout(new FillLayout());
        Rectangle minSize = shell.computeTrim(0, 0, minWidth, minHeight); 
        shell.setMinimumSize(minSize.width, minSize.height);
        shell.pack();
        shell.open();
        shell.forceActive();
        while (!shell.isDisposed()) {
            if (!LanternHub.display().readAndDispatch())
                LanternHub.display().sleep();
        }
    }

    private Image newImage(final String path) {
        final String toUse;
        final File path1 = new File(path);
        if (path1.isFile()) {
            toUse = path1.getAbsolutePath();
        } else {
            final File path2 = new File("install/common", path);
            toUse = path2.getAbsolutePath();
        }
        return new Image(LanternHub.display(), toUse);
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
        final AtomicBoolean response = new AtomicBoolean();
        LanternHub.display().syncExec(new Runnable() {
            @Override
            public void run() {
                response.set(askQuestionOnThread(title, question));
            }
        });
        log.info("Returned from sync exec");
        return response.get();
    }

    protected boolean askQuestionOnThread(final String title, 
        final String question) {
        log.info("Creating display...");
        final Shell boxShell = new Shell(LanternHub.display());
        log.info("Created display...");
        final int style = 
            SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
        final MessageBox messageBox = new MessageBox (boxShell, style);
        //messageBox.setText (I18n.tr("Exit?"));
        messageBox.setText(title);
        messageBox.setMessage (question);
            //I18n.tr("Are you sure you want to ignore the update?"));
        //final int result = messageBox.open ();
        return messageBox.open () == SWT.YES;
    }
}
