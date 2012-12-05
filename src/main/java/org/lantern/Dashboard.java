package org.lantern;

import java.awt.Point;
import java.io.File;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.commons.lang.SystemUtils;
import org.eclipse.swt.SWT;
import org.eclipse.swt.browser.Browser;
import org.eclipse.swt.browser.LocationEvent;
import org.eclipse.swt.browser.LocationListener;
import org.eclipse.swt.browser.OpenWindowListener;
import org.eclipse.swt.browser.ProgressEvent;
import org.eclipse.swt.browser.ProgressListener;
import org.eclipse.swt.browser.WindowEvent;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.layout.FillLayout;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.MessageBox;
import org.eclipse.swt.widgets.Shell;
import org.lantern.event.Events;
import org.lantern.event.MessageEvent;
import org.lantern.state.Model;
import org.lantern.win.Registry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Browser dashboard for controlling lantern.
 */
@Singleton
public class Dashboard implements MessageService, BrowserService {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    private Shell shell;
    private Browser browser;
    private boolean completed;
    
    /**
     * The display is pulled out into a separate instance variable because
     * the readAndDispatch method is called extremely frequently.
     */
    //private final Display display = LanternHub.display();
    private final SystemTray systemTray;
    private final Model model;
    
    @Inject
    public Dashboard(final SystemTray systemTray, final Model model) {
        this.systemTray = systemTray;
        this.model = model;
        Events.register(this);
    }
    
    /**
     * Opens the browser.
     */
    @Override
    public void openBrowser() {
        DisplayWrapper.getDisplay().syncExec(new Runnable() {
            @Override
            public void run() {
                buildBrowser();
                //launchChrome();
            }
        });
    }
    
    
    @Override
    public void openBrowserWhenPortReady() {
        openBrowserWhenPortReady(RuntimeSettings.getApiPort());
    }
    
    @Override
    public void openBrowserWhenPortReady(final int port) {
        LanternUtils.waitForServer(port);
        log.info("Server is running. Opening browser...");
        openBrowser();
    }
    
    @Override
    public void reopenBrowser() {
        
        openBrowser();
    }
    
    
    protected void buildBrowser() {
        log.debug("Creating shell...");
        
        // This gets around a bug in XP/SWT/IE where SWT loads IE 7 even when
        // IE 8 is on the user's system.
        if (SystemUtils.IS_OS_WINDOWS_XP) {
            System.setProperty("org.eclipse.swt.browser.IEVersion", "8000");
            
            // Make extra sure all these values are set.
            final String key = 
                "Software\\Microsoft\\Internet Explorer\\Main\\" +
                "FeatureControl\\FEATURE_BROWSER_EMULATION";

            Registry.write(key, "java.exe", 8000);
            Registry.write(key, "javaw.exe", 8000);
            Registry.write(key, "eclipse.exe", 8000);
            Registry.write(key, "lantern.exe", 8000);
            
            // We still sleep quickly here just in case there's anything
            // asynchronous under the hood.
            try {
                log.debug("Sleeping for browser...");
                Thread.sleep(600);
                log.debug("Waking");
            } catch (final InterruptedException e1) {
            }
        }
        if (this.shell != null && !this.shell.isDisposed()) {
            this.shell.forceActive();
            return;
        }
        this.shell = new Shell(DisplayWrapper.getDisplay());
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
       
        //final Monitor primary = display.getPrimaryMonitor();
        //final Rectangle bounds = primary.getBounds();
        final Rectangle rect = shell.getBounds();

        //final int x = bounds.x + (bounds.width - rect.width) / 2;
        //final int y = bounds.y + (bounds.height - rect.height) / 2;

        //shell.setLocation(x, y);
        
        final Point center = LanternUtils.getScreenCenter(rect.width, rect.height);
        shell.setLocation((int)center.getX(), (int)center.getY());
        
        log.debug("Creating new browser...");
        final int browserType;
        if (SystemUtils.IS_OS_LINUX) {
            browserType = SWT.WEBKIT;
        } else {
            browserType = SWT.NONE;
        }
        this.browser = new Browser(shell, browserType);
        this.browser.addProgressListener(new ProgressListener() {
            
            @Override
            public void completed(final ProgressEvent pe) {
                if (completed) {
                    log.debug("Ignoring multiple completed calls");
                    return;
                }
                completed = true;
                
                // We need to sync the settings before the roster to correctly
                // set everything in the state document.
                //settingsSync();
                //rosterSync();
                /*
                log.debug("Pending calls: {}", pendingCalls);
                for (final String call : pendingCalls) {
                    evaluate(call);
                }
                */
            }
            
            @Override
            public void changed(final ProgressEvent pe) {
                
            }
        });
        log.debug("Running browser: {}", browser.getBrowserType());
        browser.setSize(minWidth, minHeight);
        //browser.setBounds(0, 0, 800, 600);
        browser.setUrl(RuntimeSettings.getLocalEndpoint());

        browser.addLocationListener(new LocationListener() {
            @Override
            public void changing(LocationEvent event) {
                try {
                    final URI url = new URI(event.location);
                    final String localAuthority = RuntimeSettings.getLocalEndpoint();
                    if (openExternal(url, localAuthority)) {
                        log.info("opening external browser to {}", event.location);
                        event.doit = false;
                        LanternUtils.browseUrl(event.location);
                    }
                } catch (final URISyntaxException e) {
                    log.warn("Bad URI?", e);
                    event.doit = false;
                }
            }

            @Override
            public void changed(LocationEvent event) {}
        });

        // create a hidden browser to intercept external
        // location references that should be opened
        // in the system's native browser.
        Shell hiddenShell = new Shell(DisplayWrapper.getDisplay());
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
                if (LanternHub.settings().getSettings().getState() == SettingsState.State.LOCKED &&
                    LanternHub.settings().isLocalPasswordInitialized()) {
                    if (systemTray.isActive()) {
                        // user presented with unlock screen and just hit close
                        final int style = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
                        final MessageBox messageBox = new MessageBox (shell, style);
                        messageBox.setText ("Leave Lantern locked?");
                        final String msg =
                            "Lantern will not work while it is locked. Hide "+
                            "dashboard now? You can unlock Lantern later by "+
                            "reopening the dashboard from its icon in the "+
                            (SystemUtils.IS_OS_WINDOWS ? "system tray." :
                            "menu bar.");
                        messageBox.setMessage (msg);
                        event.doit = messageBox.open () == SWT.YES;
                        if (event.doit) {
                            // don't quit, just hide the window so user can unlock later
                            browser.close();
                        }
                    } else {
                        // no system tray so close means quit, not hide
                        final int style = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
                        final MessageBox messageBox = new MessageBox (shell, style);
                        messageBox.setText ("Quit Lantern?");
                        final String msg = "Quit Lantern?";
                        messageBox.setMessage (msg);
                        event.doit = messageBox.open () == SWT.YES;
                        if (event.doit) {
                            DisplayWrapper.getDisplay().dispose();
                            System.exit(0);
                        }
                    }
                } else if (model.isSetupComplete()) {
                    if (systemTray.isActive()) {
                        browser.stop();
                        browser.setUrl("about:blank");
                    }
                    else {
                        final int style = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
                        final MessageBox messageBox = new MessageBox (shell, style);
                        messageBox.setText ("Quit Lantern?");
                        final String msg = "Quit Lantern?";
                        messageBox.setMessage (msg);
                        event.doit = messageBox.open () == SWT.YES;
                        if (event.doit) {
                            DisplayWrapper.getDisplay().dispose();
                            System.exit(0);
                        }
                    }
                } else {
                    final int style = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
                    final MessageBox messageBox = new MessageBox (shell, style);
                    messageBox.setText ("Quit Lantern?");
                    final String msg =
                        "Lantern setup has not been completed. Quit and set up later?";
                    messageBox.setMessage (msg);
                    event.doit = messageBox.open () == SWT.YES;
                    if (event.doit) {
                        DisplayWrapper.getDisplay().dispose();
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
            if (!DisplayWrapper.getDisplay().readAndDispatch())
                DisplayWrapper.getDisplay().sleep();
        }
        hiddenShell.dispose();
    }

    private boolean openExternal(final URI url, final String localAuthority) {
        return !url.toASCIIString().startsWith("https://accounts.google.com") && 
           !url.getAuthority().equals(localAuthority);
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
        return new Image(DisplayWrapper.getDisplay(), toUse);
    }
    
    
    private static final int DEFAULT_QUESTION_FLAGS = 
        SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.YES | SWT.NO;
    
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
    
    public int askQuestion(final String title, final String question, 
        final int style) {
        if (!model.getSettings().isUiEnabled()) {
            log.info("MESSAGE BOX TITLE: "+title);
            log.info("MESSAGE BOX MESSAGE: "+question);
            return -1;
        }
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
    
    protected int askQuestionOnThread(final String title, 
        final String question, final int style) {
        log.info("Creating display...");
        final Shell boxShell = new Shell(DisplayWrapper.getDisplay());
        log.info("Created display...");
        final MessageBox messageBox = new MessageBox (boxShell, style);
        messageBox.setText(title);
        messageBox.setMessage(question);
        return messageBox.open();
    }
    
    public void rosterSync() {
        log.debug("Syncing roster");
        evaluate("loadRoster();");
    }

    public void settingsSync() {
        log.debug("Syncing state");
        evaluate("loadSettings();");
    }
    

    private final Collection<String> pendingCalls = new LinkedHashSet<String>();
    
    private void evaluate(final String call) {
        if (!this.completed) {
            log.debug("Got sync before browser has completed loading");
            pendingCalls.add(call);
            return;
        }
        if (shell.isDisposed()) {
            log.debug("Ignoring call on disposed shell.");
            return;
        }
        DisplayWrapper.getDisplay().syncExec(new Runnable() {
            @Override
            public void run() {
                browser.evaluate(call);
            } 
        });
    }

    @Override
    public void start() throws Exception {
        // TODO Auto-generated method stub
        
    }

    @Override
    public void stop() {
        if (DisplayWrapper.getDisplay() != null) {
            DisplayWrapper.getDisplay().dispose();
        }
    }

    @Override
    @Subscribe
    public void onMessageEvent(MessageEvent me) {
        showMessage(me.getTitle(), me.getMsg());
    }
}
