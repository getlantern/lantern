package org.lantern;

import java.io.File;
import java.util.concurrent.atomic.AtomicInteger;

import org.eclipse.swt.SWT;
import org.eclipse.swt.browser.Browser;
import org.eclipse.swt.browser.LocationEvent;
import org.eclipse.swt.browser.LocationListener;
import org.eclipse.swt.browser.OpenWindowListener;
import org.eclipse.swt.browser.WindowEvent;
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

    public Dashboard() {
        configureShutdownHook();
    }

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
        final Image large = newImage("128on.png");
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
            LanternHub.settings().getApiPort());

        // create a hidden browser to intercept external
        // location references that should be openend
        // in the system's native browser.
        Shell hiddenShell = new Shell(LanternHub.display());
        final Browser externalBrowser = new Browser(hiddenShell, SWT.NONE);

        externalBrowser.addLocationListener(new LocationListener() {
            @Override
            public void changing(LocationEvent event) {
                // launch external browser with link,
                // but don't actually go there.
                event.doit = false;
                LanternUtils.browseUrl(event.location);
            }

            @Override
            public void changed(LocationEvent event) {}
        });

        browser.addOpenWindowListener(new OpenWindowListener() {
            @Override
            public void open(WindowEvent e) {
                e.browser = externalBrowser;
            }
        });

        shell.addListener (SWT.Close, new Listener () {
            @Override
            public void handleEvent(final Event event) {
                if (LanternHub.settings().isInitialSetupComplete()) {
                    browser.stop();
                    browser.setUrl("about:blank");
                } else {
                    final int style = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
                    final MessageBox messageBox = new MessageBox (shell, style);
                    messageBox.setText ("Quit Lantern?");
                    final String msg = 
                        "Lantern setup has not been completed. Quit and set up later?";
                    messageBox.setMessage (msg);
                    event.doit = messageBox.open () == SWT.YES;
                    if (event.doit) {
                        LanternHub.display().dispose();
                        System.exit(0);
                    }
                }
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
        hiddenShell.dispose();
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
    
    
    static final int DEFAULT_QUESTION_FLAGS = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
    
    /**
     * Shows a message to the user using a dialog box;
     * 
     * @param title The title of the dialog box.
     * @param msg The message.
     */
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
    
    public int askQuestion(final String title, final String question, final int style) {
        final AtomicInteger response = new AtomicInteger();
        LanternHub.display().syncExec(new Runnable() {
            @Override
            public void run() {
                response.set(askQuestionOnThread(title, question, style));
            }
        });
        log.info("Returned from sync exec");
        return response.get();
    }
    
    protected int askQuestionOnThread(final String title, 
        final String question, final int style) {
        log.info("Creating display...");
        final Shell boxShell = new Shell(LanternHub.display());
        log.info("Created display...");
        final MessageBox messageBox = new MessageBox (boxShell, style);
        messageBox.setText(title);
        messageBox.setMessage(question);
        return messageBox.open();
    }
    
    public void configureShutdownHook() {
        final Thread hook = new Thread(new Runnable() {
            @Override
            public void run() {
                boolean finished = false;
                while (!finished) {
                    try {
                        Proxifier.stopProxying();
                        finished = true;
                    } catch (final Proxifier.ProxyConfigurationError e) {
                        log.error("Failed to unconfigure proxy.");
                        // XXX i18n
                        final String question = "Failed to change the system proxy settings.\n\n" + 
                        "If Lantern remains as the system proxy after being shut down, " + 
                        "you will need to manually change the system's network proxy settings " + 
                        "in order to access the web.\n\nTry again?";
                        final int response = askQuestion("Proxy Settings", question,
                            SWT.APPLICATION_MODAL | SWT.ICON_WARNING | SWT.RETRY | SWT.CANCEL);
                        if (response == SWT.CANCEL) {
                            finished = true;
                        }
                        else {
                            log.info("Trying again");
                        }
                    }
                }
            }
        }, "Unset-Web-Proxy-Thread");
        LanternHub.display().disposeExec(hook);
    }
}
