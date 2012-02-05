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

    /**
     * Creates a new system tray handler class.
     * 
     * @param display The SWT display. 
     */
    public SystemTrayImpl() {
        LanternHub.register(this);
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
            
            final MenuItem dashboardItem = new MenuItem(menu, SWT.PUSH);
            dashboardItem.setText("Open Dashboard"); // XXX i18n
            dashboardItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    LanternHub.jettyLauncher().openBrowserWhenReady();
                }
            });
            
            
            new MenuItem(menu, SWT.SEPARATOR);
            
            final MenuItem quitItem = new MenuItem(menu, SWT.PUSH);
            quitItem.setText("Quit Lantern"); // XXX i18n
            
            quitItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    System.out.println("Got exit call");
                    display.dispose();
                    LanternHub.xmppHandler().disconnect();
                    System.exit(0);
                }
            });

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
            changeIcon("16off.png");
            break;
        }
        case CONNECTING: {
            // This could be changed to yellow.
            changeIcon("16off.png");
            break;
        }
        case CONNECTED: {
            changeIcon("16on.png");
            break;
        }
        case DISCONNECTING:
            // This could be changed to yellow?
            changeIcon("16off.png");
            break;
        }

    }

    private void changeIcon(final String fileName) {
        if (display.isDisposed()) {
            log.info("Ingoring call since display is disposed");
            return;
        }
        display.asyncExec (new Runnable () {
            @Override
            public void run () {
                if (SystemUtils.IS_OS_MAC_OSX) {
                    log.info("Customizing image on OSX...");
                    final Image image = newImage(fileName, 16, 16);
                    setImage(image);
                }
            }
        });
    }

}
