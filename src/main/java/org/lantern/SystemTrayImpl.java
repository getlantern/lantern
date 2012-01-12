package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
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

import com.google.common.eventbus.Subscribe;

/**
 * Class for handling all system tray interactions.
 */
public class SystemTrayImpl implements SystemTray {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private Display display;
    private Shell shell;
    private TrayItem trayItem;
    private MenuItem updateItem;
    private Menu menu;
    private Map<String, String> updateData;
    private MenuItem stopItem;
    private MenuItem startItem;
    private boolean proxying;

    /**
     * Creates a new system tray handler class.
     * 
     * @param display The SWT display. 
     */
    public SystemTrayImpl() {
        LanternHub.eventBus().register(this);
    }

    @Override
    public void createTray() {
        this.display = LanternHub.display();
        this.shell = new Shell(display);
        
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
            this.trayItem.setToolTipText(
                I18n.tr("Lantern ")+LanternConstants.VERSION);
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
            /*
            final MenuItem dashboardItem = new MenuItem(menu, SWT.PUSH);
            dashboardItem.setText(I18n.tr("Open Lantern Dashboard"));
            dashboardItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    log.info("Opening browser!!");
                    LanternHub.jettyLauncher().openBrowserWhenReady();
                }
            });
            */
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
            if (LanternHub.settings().isGetMode()) {
                stopItem = new MenuItem(menu, SWT.PUSH);
                stopItem.setText(I18n.tr("Stop Lantern "));
                stopItem.setEnabled(false);
                stopItem.addListener (SWT.Selection, new Listener () {
                    @Override
                    public void handleEvent (final Event event) {
                        log.info("Stopping Lantern!!");
                        Configurator.stopProxying();
                        LanternHub.xmppHandler().disconnect();
                    }
                });
                
                startItem = new MenuItem(menu, SWT.PUSH);
                startItem.setText(I18n.tr("Start Lantern "));
                startItem.setEnabled(false);
                startItem.addListener (SWT.Selection, new Listener () {
                    @Override
                    public void handleEvent (final Event event) {
                        log.info("Starting Lantern!!");
                        try {
                            LanternHub.xmppHandler().connect();
                            Configurator.startProxying();
                        } catch (final IOException e) {
                            log.info("Could not connect", e);
                        }
                    }
                });
                log.info("Added start and stop items");
            }
            */
            
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
            
            final MenuItem dashboardItem = new MenuItem(menu, SWT.PUSH);
            dashboardItem.setText("Open Dashboard");
            dashboardItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    LanternHub.jettyLauncher().openBrowserWhenReady();
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

    @Subscribe
    public void onConnectivityStateChanged(
        final ConnectivityStatusChangeEvent csce) {
        final ConnectivityStatus cs = csce.getConnectivityStatus();
        log.info("Got connectivity state changed {}", cs);
        switch (cs) {
        case DISCONNECTED: {
            // This could be changed to a red icon.
            changeIcon(false, "16off.png");
            break;
        }
        case CONNECTING: {
            // This could be changed to yellow.
            changeIcon(false, "16off.png");
            break;
        }
        case CONNECTED: {
            changeIcon(true, "16on.png");
            break;
        }
        case DISCONNECTING:
            // This could be changed to yellow?
            changeIcon(false, "16off.png");
            break;
        }

    }

    private void changeIcon(final boolean connected, final String fileName) {
        display.asyncExec (new Runnable () {
            @Override
            public void run () {
                if (LanternHub.settings().isGetMode()) {
                    stopItem.setEnabled(connected);
                    startItem.setEnabled(!connected);
                }
                if (SystemUtils.IS_OS_MAC_OSX) {
                    log.info("Customizing image on OSX...");
                    final Image image = newImage(fileName, 16, 16);
                    setImage(image);
                }
            }
        });
    }

    @Subscribe
    public void onProxyEvent(final ProxyingEvent event) {
        this.proxying = event.isProxying();
        if (stopItem == null || startItem == null) {
            log.info("NOT IN PROXY MODE");
            return;
        }
        if (display.isDisposed()) {
            log.info("Display is disposed. Already shut down?");
            return;
        }
        display.asyncExec (new Runnable () {
            @Override
            public void run () {
                log.info("Setting start stop button state.");
                stopItem.setEnabled(proxying);
                startItem.setEnabled(!proxying);
                showRestartBrowserMessage();
            }
        });
    }
}
