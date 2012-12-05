package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.InputStream;
import java.util.Map;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.SystemUtils;
import org.eclipse.swt.SWT;
import org.eclipse.swt.events.SelectionEvent;
import org.eclipse.swt.events.SelectionListener;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.Menu;
import org.eclipse.swt.widgets.MenuItem;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.widgets.Tray;
import org.eclipse.swt.widgets.TrayItem;
import org.lantern.event.Events;
import org.lantern.event.GoogleTalkStateEvent;
import org.lantern.event.QuitEvent;
import org.lantern.event.UpdateEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class for handling all system tray interactions.
 */
@Singleton
public class SystemTrayImpl implements SystemTray {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private Shell shell;
    private TrayItem trayItem;
    private MenuItem connectionStatusItem;
    private MenuItem updateItem;
    private Menu menu;
    private Map<String, Object> updateData;
    private boolean active = false;

    private final static String LABEL_DISCONNECTED = "Lantern: Not connected";
    private final static String LABEL_CONNECTING = "Lantern: Connecting...";
    private final static String LABEL_CONNECTED = "Lantern: Connected";
    private final static String LABEL_DISCONNECTING = "Lantern: Disconnecting...";
    
    // could be changed to red/yellow/green
    private final static String ICON_DISCONNECTED  = "16off.png";
    private final static String ICON_CONNECTING    = "16off.png"; 
    private final static String ICON_CONNECTED     = "16on.png";
    private final static String ICON_DISCONNECTING = "16off.png";
    //private final XmppHandler handler;
    private final BrowserService browserService;
    
    /**
     * Creates a new system tray handler class.
     * 
     * @param display The SWT display. 
     */
    @Inject
    public SystemTrayImpl(final BrowserService browserService) {
        this.browserService = browserService;
        Events.register(this);
    }
    

    @Override
    public void start() {
        createTray();
    }

    @Override
    public void stop() {
        DisplayWrapper.getDisplay().asyncExec (new Runnable () {
            @Override
            public void run () {
                if (DisplayWrapper.getDisplay().isDisposed()) {
                    return;
                }
                try {
                    DisplayWrapper.getDisplay().dispose();
                } catch (final Throwable t) {
                    log.info("Exception disposing display?", t);
                }
            }
        });
    }

    @Override
    public boolean isSupported() {
        return DisplayWrapper.getDisplay().getSystemTray() != null;
    }

    @Override
    public void createTray() {
        log.debug("Creating shell");
        this.shell = new Shell(DisplayWrapper.getDisplay());
        log.debug("Created shell");
        
        DisplayWrapper.getDisplay().asyncExec (new Runnable () {
            @Override
            public void run () {
                createTrayInternal();
            }
        });
    }
    
    private void createTrayInternal() {
        final Tray tray = DisplayWrapper.getDisplay().getSystemTray ();
        if (tray == null) {
            log.warn("The system tray is not available");
        } else {
            log.info("Creating system tray...");
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
            
            this.connectionStatusItem = new MenuItem(menu, SWT.PUSH);
            connectionStatusItem.setText(LABEL_DISCONNECTED); // XXX i18n 
            connectionStatusItem.setEnabled(false);
            
            final MenuItem dashboardItem = new MenuItem(menu, SWT.PUSH);
            dashboardItem.setText("Open Dashboard"); // XXX i18n
            dashboardItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    browserService.reopenBrowser();
                }
            });
            
            
            new MenuItem(menu, SWT.SEPARATOR);
            
            final MenuItem quitItem = new MenuItem(menu, SWT.PUSH);
            quitItem.setText("Quit Lantern"); // XXX i18n
            
            quitItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    System.out.println("Got exit call");
                    
                    // This tells things like the Proxifier to stop proxying.
                    Events.eventBus().post(new QuitEvent());
                    
                    DisplayWrapper.getDisplay().dispose();
                    
                    // We call this primarily because we need to make sure to
                    // remove any UPnP and NAT-PMP port mappings.
                    //handler.disconnect();
                    //LanternHub.jettyLauncher().stop();
                    
                    // We don't need to actively close all open resources --
                    // System.exit will cleanly shutdown the JVM.
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
                imageName = ICON_DISCONNECTED;
            } else {
                imageName = ICON_CONNECTED;
            }
            final Image image = newImage(imageName, 16, 16);
            setImage(image);
            
            if (SystemUtils.IS_OS_WINDOWS || SystemUtils.IS_OS_LINUX) {
                this.trayItem.addSelectionListener(new SelectionListener() {
                    @Override
                    public void widgetSelected(SelectionEvent se) {
                        log.debug("opening dashboard");
                        browserService.reopenBrowser();
                    }
                    
                    @Override
                    public void widgetDefaultSelected(SelectionEvent se) {
                        log.warn("default selection event unhandled");
                    }
                });
            }
            this.active = true;
        }
    }

    private void setImage(final Image image) {
        DisplayWrapper.getDisplay().asyncExec (new Runnable () {
            @Override
            public void run () {
                trayItem.setImage (image);
            }
        });
    }
    
    private void setStatusLabel(final String status) {
        DisplayWrapper.getDisplay().asyncExec (new Runnable () {
            @Override
            public void run () {
                // XXX i18n 
                connectionStatusItem.setText(status);
            }
        });
    }

    private Image newImage(final String name, int width, int height) {
        final File iconFile;
        final File iconCandidate1 = new File("install/common/"+name);
        if (iconCandidate1.isFile()) {
            log.debug("Using install dir icon");
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
            return new Image (DisplayWrapper.getDisplay(), is);
        } catch (final FileNotFoundException e) {
            log.error("Could not find icon file: "+iconFile, e);
        } finally {
            IOUtils.closeQuietly(is);
        }
        return new Image (DisplayWrapper.getDisplay(), width, height);
    }

    @Override
    public void addUpdate(final Map<String, Object> data) {
        log.info("Adding update data: {}", data);
        if (this.updateData != null && this.updateData.equals(data)) {
            log.info("Ignoring duplicate update data");
            return;
        }
        this.updateData = data;
        DisplayWrapper.getDisplay().asyncExec (new Runnable () {
            @Override
            public void run () {
                if (updateItem == null) {
                    updateItem = new MenuItem(menu, SWT.PUSH, 0);
                    updateItem.addListener (SWT.Selection, new Listener () {
                        @Override
                        public void handleEvent (final Event event) {
                            log.info("Got update call");
                            NativeUtils.openUri((String) updateData.get(
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
    public void onUpdate(final UpdateEvent update) {
        addUpdate(update.getData());
    }

    @Subscribe
    public void onConnectivityStateChanged(final GoogleTalkStateEvent event) {
        final GoogleTalkState state = event.getState();
        switch (state) {
        case LOGIN_FAILED:
            changeIcon(ICON_DISCONNECTED);
            changeStatusLabel(LABEL_DISCONNECTED);
            break;
        case connected:
            changeIcon(ICON_CONNECTED);
            changeStatusLabel(LABEL_CONNECTED);
            break;
        case connecting:
            changeIcon(ICON_CONNECTING);
            changeStatusLabel(LABEL_CONNECTING);
            break;
        case notConnected:
            changeIcon(ICON_DISCONNECTED);
            changeStatusLabel(LABEL_DISCONNECTED);
            break;
        default:
            break;
        }
    }

    @Override
    public boolean isActive() {
        return this.active;
    }

    private void changeIcon(final String fileName) {
        if (DisplayWrapper.getDisplay().isDisposed()) {
            log.info("Ingoring call since display is disposed");
            return;
        }
        DisplayWrapper.getDisplay().asyncExec (new Runnable () {
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
    
    private void changeStatusLabel(final String status) {
        if (DisplayWrapper.getDisplay().isDisposed()) {
            log.info("Ingoring call since display is disposed");
            return;
        }
        setStatusLabel(status);
    }

}
