package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.InputStream;
import java.util.Map;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.SystemUtils;
import org.apache.commons.lang3.StringUtils;
import org.eclipse.swt.SWT;
import org.eclipse.swt.events.SelectionEvent;
import org.eclipse.swt.events.SelectionListener;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.Menu;
import org.eclipse.swt.widgets.MenuItem;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.widgets.Tray;
import org.eclipse.swt.widgets.TrayItem;
import org.lantern.event.Events;
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
public class SystemTrayImpl extends BaseSystemTray {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private Shell shell;
    private TrayItem trayItem;
    private MenuItem connectionStatusItem;
    private MenuItem updateItem;
    private Menu menu;
    private Map<String, Object> updateData;
    private boolean active = false;

    private final BrowserService browserService;
    private String connectionStatusText;
    private Image trayItemImage;

    /**
     * Creates a new system tray handler class.
     *
     * @param display The SWT display.
     */
    @Inject
    public SystemTrayImpl(final BrowserService browserService) {
        super();
        this.browserService = browserService;
    }

    @Override
    public void start() {
        createTray();
    }

    @Override
    public void stop() {
        try {
            final Display display = DisplayWrapper.getDisplay();
            if (!display.isDisposed()) {
                display.asyncExec(new Runnable() {
                    @Override
                    public void run() {
                        if (display.isDisposed()) {
                            return;
                        }
                        try {
                            display.dispose();
                        } catch (final Throwable t) {
                            log.info("Exception disposing display?", t);
                        }
                    }
                });
            }
        } catch (final Throwable t) {
            log.info("Exception disposing display?", t);
        }
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

        createTrayInternal();
    }

    private void createTrayInternal() {
        final Tray tray = DisplayWrapper.getDisplay().getSystemTray ();
        if (tray == null) {
            log.warn("The system tray is not available");
        } else {
            log.info("Creating system tray...");
            this.trayItem = new TrayItem (tray, SWT.NONE);
            this.trayItem.setToolTipText(
                I18n.tr("Lantern ")+LanternClientConstants.VERSION);

            // Another thread could have set the tray item image before the
            // tray item was created.
            if (this.trayItemImage != null) {
                this.trayItem.setImage(trayItemImage);
            }
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

            // Other threads can set the label before we've constructed the
            // menu item, so check for it.
            if (StringUtils.isNotBlank(connectionStatusText)) {
                connectionStatusItem.setText(connectionStatusText);
            } else {
                connectionStatusItem.setText(LABEL_DISCONNECTED); // XXX i18n
            }
            connectionStatusItem.setEnabled(false);

            final MenuItem dashboardItem = new MenuItem(menu, SWT.PUSH);
            dashboardItem.setText("Show Lantern"); // XXX i18n
            dashboardItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    log.debug("Reopening browser?");
                    browserService.reopenBrowser();
                }
            });

            new MenuItem(menu, SWT.SEPARATOR);

            final MenuItem quitItem = new MenuItem(menu, SWT.PUSH);
            quitItem.setText("Quit Lantern"); // XXX i18n

            quitItem.addListener (SWT.Selection, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    log.debug("Got exit call");

                    // This tells things like the Proxifier to stop proxying.
                    Events.eventBus().post(new QuitEvent());
                    DisplayWrapper.getDisplay().dispose();

                    System.exit(0);
                }
            });

            trayItem.addListener (SWT.MenuDetect, new Listener () {
                @Override
                public void handleEvent (final Event event) {
                    log.debug("Setting menu visible");
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
                        log.debug("default selection event unhandled");
                    }
                });
                log.debug("Added selection");
            }
            this.active = true;
        }
        log.debug("Finished creating tray...");
    }

    private void setImage(final Image image) {
        DisplayWrapper.getDisplay().asyncExec (new Runnable () {
            @Override
            public void run () {
                if (trayItem == null) {
                    trayItemImage = image;
                } else {
                    trayItem.setImage (image);
                }
            }
        });
    }

    private void setStatusLabel(final String status) {
        DisplayWrapper.getDisplay().asyncExec (new Runnable () {
            @Override
            public void run () {
                // XXX i18n
                if (connectionStatusItem == null) {
                    connectionStatusText = status;
                } else {
                    connectionStatusItem.setText(status);
                }
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
            log.error("Still no icon file at: {}", iconFile.getAbsolutePath());
            return null;
        }
        InputStream is = null;
        try {
            is = new FileInputStream(iconFile);
            log.debug("Returning file at: {}", iconFile.getAbsolutePath());
            return new Image (DisplayWrapper.getDisplay(), is);
        } catch (final FileNotFoundException e) {
            log.error("Could not find icon file: "+iconFile, e);
        } finally {
            IOUtils.closeQuietly(is);
        }
        log.debug("Returning blank image");
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

    @Override
    public boolean isActive() {
        return this.active;
    }

    @Override
    protected void changeIcon(final String fileName) {
        if (DisplayWrapper.getDisplay().isDisposed()) {
            log.info("Ignoring call since display is disposed");
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

    @Override
    protected void changeLabel(final String status) {
        if (DisplayWrapper.getDisplay().isDisposed()) {
            log.info("Ingoring call since display is disposed");
            return;
        }
        setStatusLabel(status);
    }

}
