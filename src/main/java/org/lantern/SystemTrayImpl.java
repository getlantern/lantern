package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.InputStream;
import java.util.Map;

import org.apache.commons.lang.SystemUtils;
import org.eclipse.swt.SWT;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.Menu;
import org.eclipse.swt.widgets.MenuItem;
import org.eclipse.swt.widgets.MessageBox;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.widgets.Tray;
import org.eclipse.swt.widgets.TrayItem;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for handling all system tray interactions.
 */
public class SystemTrayImpl implements SystemTray {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final Display display;
    private final Shell shell;
    private TrayItem trayItem;
    private MenuItem updateItem;
    private Menu menu;
    private Map<String, String> updateData;
    private MenuItem stopItem;
    private MenuItem startItem;

    /**
     * Creates a new system tray handler class.
     * 
     * @param display The SWT display. 
     */
    public SystemTrayImpl(final Display display) {
        this.display = display;
        this.shell = new Shell(display);
    }

    @Override
    public void createTray() {
        display.asyncExec (new Runnable () {
            @Override
            public void run () {
                createTrayInternal();
            }
        });
    }
    
    private void createTrayInternal() {
        final Tray tray = display.getSystemTray ();
        if (tray == null) {
            System.out.println ("The system tray is not available");
        } else {
            this.trayItem = new TrayItem (tray, SWT.NONE);
            this.trayItem.setToolTipText(I18n.tr("Lantern ")+LanternConstants.VERSION);
            this.trayItem.addListener (SWT.Show, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    System.out.println("show");
                }
            });
            this.trayItem.addListener (SWT.Hide, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    System.out.println("hide");
                }
            });

            this.menu = new Menu (shell, SWT.POP_UP);
            final MenuItem dashboardItem = new MenuItem(menu, SWT.PUSH);
            dashboardItem.setText(I18n.tr("Open Internet Dashboard"));
            dashboardItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    log.info("Stopping Lantern!!");
                    display.asyncExec (new Runnable () {
                        @Override
                        public void run () {
                            log.info("Setting start stop button state.");
                            LanternHub.jettyLauncher().openBrowserWhenReady();
                        }
                    });
                }
            });
            /*
            final MenuItem aboutItem = new MenuItem(menu, SWT.PUSH);
            aboutItem.setText(I18n.tr("About"));
            aboutItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    System.out.println("Got about call");
                    final int style = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.OK;
                    final MessageBox messageBox = new MessageBox (shell, style);
                    messageBox.setText (I18n.tr("Lantern"));
                    messageBox.setMessage (
                        "Running Lantern "+LanternConstants.VERSION);
                    shell.forceActive();
                    event.doit = messageBox.open () == SWT.YES;
                    shell.forceActive();
                }
            });
            */
            
            stopItem = new MenuItem(menu, SWT.PUSH);
            stopItem.setText(I18n.tr("Stop Lantern "));
            stopItem.setEnabled(false);
            stopItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    log.info("Stopping Lantern!!");
                    display.asyncExec (new Runnable () {
                        @Override
                        public void run () {
                            log.info("Setting start stop button state.");
                            stopItem.setEnabled(false);
                            startItem.setEnabled(true);
                            showRestartBrowserMessage();
                        }
                    });
                    Configurator.stopProxying();
                }
            });
            
            startItem = new MenuItem(menu, SWT.PUSH);
            startItem.setText(I18n.tr("Start Lantern "));
            startItem.setEnabled(false);
            startItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    log.info("Starting Lantern!!");
                    display.asyncExec (new Runnable () {
                        @Override
                        public void run () {
                            log.info("Setting start stop button state.");
                            stopItem.setEnabled(true);
                            startItem.setEnabled(false);
                            showRestartBrowserMessage();
                        }
                    });
                    Configurator.startProxying();
                }
            });
            
            final MenuItem configItem = new MenuItem(menu, SWT.PUSH);
            configItem.setText(I18n.tr("Configure Lantern ")+LanternConstants.VERSION);
            configItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    System.out.println("Got config call");
                    /*
                    FileDialog fd = new FileDialog(shell, SWT.OPEN);
                    fd.setText("Open");
                    //fd.setFilterPath("C:/");
                    //String[] filterExt = { "*.txt", "*.doc", ".rtf", "*.*" };
                    //fd.setFilterExtensions(filterExt);
                    String selected = fd.open();
                    shell.forceActive();
                    System.out.println(selected);
                    */
                    
                    final LanternBrowser browser = new LanternBrowser(true);
                    browser.install();
                }
            });
            
            
            new MenuItem(menu, SWT.SEPARATOR);
            
            final MenuItem quitItem = new MenuItem(menu, SWT.PUSH);
            quitItem.setText(I18n.tr("Quit"));
            
            quitItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    System.out.println("Got exit call");
                    display.dispose();
                    System.exit(0);
                }
            });
            //menu.setDefaultItem(quitItem);

            trayItem.addListener (SWT.MenuDetect, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    System.out.println("Setting menu visible");
                    menu.setVisible (true);
                }
            });
            
            final String imageName;
            if (SystemUtils.IS_OS_MAC_OSX) {
                imageName = "16off.png";
            } else {
                imageName = "16on.png";
            }
            final Image image = newImage(imageName, 16, 16);
            setImage(image);
        }
    }
    
    private void showRestartBrowserMessage() {
        if (SystemUtils.IS_OS_MAC_OSX) {
            log.info("Restart doesn't seem to be necessary on OSX");
            return;
        }
        final int style = SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.OK;
        final MessageBox messageBox = new MessageBox (shell, style);
        messageBox.setText (I18n.tr("Browser Restart"));
        messageBox.setMessage (
            I18n.tr("You may have to restart your browser for these changes to take effect."));
        messageBox.open ();
    }

    private void setImage(final Image image) {
        display.asyncExec (new Runnable () {
            @Override
            public void run () {
                trayItem.setImage (image);
            }
        });
    }

    private Image newImage(final String name, int width, int height) {
        final File iconFile;
        final File iconCandidate1 = new File("install/common/"+name);
        if (iconCandidate1.isFile()) {
            iconFile = iconCandidate1;
        } else {
            iconFile = new File(name);
        }
        if (!iconFile.isFile()) {
            log.error("Still no icon file at: " + iconFile);
        }
        InputStream is = null;
        try {
            is = new FileInputStream(iconFile);
            return new Image (display, is);
        } catch (final FileNotFoundException e) {
            log.error("Could not find icon file: "+iconFile, e);
        } 
        return new Image (display, width, height);
    }
    
    @Override
    public void activate() {
        log.info("Activating Lantern icon");
        if (!SystemUtils.IS_OS_MAC_OSX) {
            log.info("Ignoring activation since we're not on OSX...");
            return;
        }
        display.asyncExec (new Runnable () {
            @Override
            public void run () {
                final Image image = newImage("16on.png", 16, 16);
                setImage(image);
                if (LanternUtils.shouldProxy()) {
                    stopItem.setEnabled(true);
                }
            }
        });
    }
    

    @Override
    public void addUpdate(final Map<String, String> data) {
        log.info("Adding update data: {}", data);
        this.updateData = data;
        display.asyncExec (new Runnable () {
            @Override
            public void run () {
                if (updateItem == null) {
                    updateItem = new MenuItem(menu, SWT.PUSH, 0);
                    updateItem.addListener (SWT.Selection, new Listener () {
                        @Override
                        public void handleEvent (final Event event) {
                            log.info("Got update call");
                            NativeUtils.openUri(updateData.get(
                                LanternConstants.UPDATE_URL_KEY));
                        }
                    });
                }
                updateItem.setText(I18n.tr("Update to Lantern ")+
                    data.get(LanternConstants.UPDATE_VERSION_KEY));
            }
        });
    }
}
