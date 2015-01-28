package org.lantern;

import static org.lantern.Tr.*;

import java.awt.AWTException;
import java.awt.Image;
import java.awt.MenuItem;
import java.awt.PopupMenu;
import java.awt.SystemTray;
import java.awt.TrayIcon;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.File;
import java.util.Map;

import javax.swing.ImageIcon;
import javax.swing.SwingUtilities;

import org.apache.commons.lang.SystemUtils;
import org.apache.commons.lang3.StringUtils;
import org.lantern.browser.BrowserService;
import org.lantern.event.Events;
import org.lantern.event.GoogleTalkStateEvent;
import org.lantern.event.ProxyConnectedEvent;
import org.lantern.event.QuitEvent;
import org.lantern.event.UpdateEvent;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class for handling all system tray interactions.
 */
@Singleton
public class SystemTrayImpl implements org.lantern.SystemTray {

    private static final Logger log = LoggerFactory
            .getLogger(SystemTrayImpl.class);
    private SystemTray tray;
    private TrayIcon trayIcon;
    private PopupMenu menu;
    private MenuItem connectionStatusItem;
    private MenuItem updateItem;
    private Map<String, Object> updateData;
    private boolean active = false;

    private final static String LABEL_DISCONNECTED = tr("TRAY_NOT_CONNECTED");
    private final static String LABEL_CONNECTING = tr("TRAY_CONNECTING");
    private final static String LABEL_CONNECTED = tr("TRAY_CONNECTED");

    private final static String ICON_DISCONNECTED = "16off.png";
    private final static String ICON_CONNECTING = "16off.png";
    private final static String ICON_CONNECTED = "16on.png";

    private final BrowserService browserService;
    private final Model model;
    private String connectionStatusText;
    private Image trayImage;

    /**
     * Creates a new system tray handler class.
     * 
     */
    @Inject
    public SystemTrayImpl(final BrowserService browserService,
            final Model model) {
        this.browserService = browserService;
        this.model = model;
        Events.register(this);
    }

    @Override
    public void start() {
        log.debug("Starting system tray");
        createTray();
    }

    @Override
    public void stop() {
        SwingUtilities.invokeLater(new Runnable() {
            @Override
            public void run() {
                tray.remove(trayIcon);
            }
        });
    }

    @Override
    public boolean isSupported() {
        return SystemTray.isSupported();
    }

    @Override
    public void createTray() {
        SwingUtilities.invokeLater(new Runnable() {
            @Override
            public void run() {
                doCreateTray();
            }
        });
    }

    private void doCreateTray() {
        tray = SystemTray.getSystemTray();
        if (tray == null) {
            log.warn("The system tray is not available");
        } else {
            log.info("Creating system tray...");
            // Another thread could have set the tray item image before the
            // tray item was created.
            if (trayImage == null) {
                // Image was not yet set
                final String imageName;
                if (SystemUtils.IS_OS_MAC_OSX) {
                    imageName = ICON_DISCONNECTED;
                } else {
                    imageName = ICON_CONNECTED;
                }
                trayImage = newImage(imageName);
            }
            this.trayIcon = new TrayIcon(trayImage);
            trayIcon.setToolTip(
                    tr("LANTERN") + " " + LanternClientConstants.VERSION);

            this.menu = new PopupMenu();

            this.connectionStatusItem = new MenuItem();
            // Other threads can set the label before we've constructed the
            // menu item, so check for it.
            if (StringUtils.isNotBlank(connectionStatusText)) {
                connectionStatusItem.setLabel(connectionStatusText);
            } else {
                connectionStatusItem.setLabel(LABEL_DISCONNECTED);
            }
            connectionStatusItem.setEnabled(false);
            menu.add(connectionStatusItem);

            final MenuItem dashboardItem = new MenuItem(tr("TRAY_SHOW_LANTERN"));
            dashboardItem.addActionListener(new ActionListener() {
                @Override
                public void actionPerformed(ActionEvent e) {
                    log.debug("Reopening browser?");
                    browserService.reopenBrowser();
                }
            });
            menu.add(dashboardItem);

            menu.addSeparator();

            final MenuItem quitItem = new MenuItem(tr("TRAY_QUIT"));
            quitItem.addActionListener(new ActionListener() {
                @Override
                public void actionPerformed(ActionEvent e) {
                    log.debug("Got exit call");

                    // This tells things like the Proxifier to stop proxying.
                    Events.eventBus().post(new QuitEvent());
                    System.exit(0);
                }
            });
            menu.add(quitItem);

            trayIcon.setPopupMenu(menu);

            if (SystemUtils.IS_OS_WINDOWS || SystemUtils.IS_OS_LINUX) {
                trayIcon.addActionListener(new ActionListener() {
                    @Override
                    public void actionPerformed(ActionEvent e) {
                        log.debug("opening dashboard");
                        browserService.reopenBrowser();
                    }
                });
                log.debug("Added selection");
            }

            try {
                tray.add(trayIcon);
            } catch (AWTException e) {
                System.out.println("TrayIcon could not be added.");
            }

            this.active = true;
        }
        log.debug("Finished creating tray...");
    }

    private void setImage(final Image image) {
        SwingUtilities.invokeLater(new Runnable() {
            @Override
            public void run() {
                if (trayIcon == null) {
                    log.warn("Tray icon not created yet?");
                    trayImage = image;
                } else {
                    trayIcon.setImage(image);
                }
            }
        });
    }

    private void setStatusLabel(final String status) {
        SwingUtilities.invokeLater(new Runnable() {
            @Override
            public void run() {
                // XXX i18n
                if (connectionStatusItem == null) {
                    connectionStatusText = status;
                } else {
                    connectionStatusItem.setLabel(status);
                }
            }
        });
    }

    protected static Image newImage(String name) {
        final File iconFile;
        final File iconCandidate1 = new File("install/common/" + name);
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

        return (new ImageIcon(iconFile.getAbsolutePath())).getImage()
                .getScaledInstance(16, 16, Image.SCALE_SMOOTH);
    }

    @Override
    public void addUpdate(final Map<String, Object> data) {
        log.info("Adding update data: {}", data);
        if (this.updateData != null && this.updateData.equals(data)) {
            log.info("Ignoring duplicate update data");
            return;
        }
        this.updateData = data;
        SwingUtilities.invokeLater(new Runnable() {
            @Override
            public void run() {
                if (updateItem == null) {
                    String label = tr("TRAY_UPDATE") + " " +
                            data.get(LanternConstants.UPDATE_KEY);
                    updateItem = new MenuItem(label);
                    updateItem.addActionListener(new ActionListener() {
                        @Override
                        public void actionPerformed(ActionEvent e) {
                            log.info("Got update call");
                            NativeUtils.openUri((String) updateData.get(
                                    "installerUrl"));
                        }
                    });
                }
            }
        });
    }

    @Subscribe
    public void onUpdate(final UpdateEvent update) {
        addUpdate(update.getData());
    }

    @Subscribe
    public void onConnectivityStateChanged(final ProxyConnectedEvent csce) {
        log.debug("Proxy connected");
        if (!this.model.getSettings().isUiEnabled()) {
            log.info("Ignoring event with UI disabled");
            return;
        }
        onConnectivityStatus(ConnectivityStatus.CONNECTED);
    }

    @Subscribe
    public void onGoogleTalkState(final GoogleTalkStateEvent event) {
        if (model.getSettings().getMode() == Mode.get) {
            log.debug("Not linking Google Talk state to connectivity " +
                    "state in get mode");
            return;
        }
        final GoogleTalkState state = event.getState();
        final ConnectivityStatus cs;
        switch (state) {
        case connected:
            cs = ConnectivityStatus.CONNECTED;
            break;
        case notConnected:
            cs = ConnectivityStatus.DISCONNECTED;
            break;
        case LOGIN_FAILED:
            cs = ConnectivityStatus.DISCONNECTED;
            break;
        case connecting:
            cs = ConnectivityStatus.CONNECTING;
            break;
        default:
            log.error("Should never get here...");
            cs = ConnectivityStatus.DISCONNECTED;
            break;
        }
        onConnectivityStatus(cs);
    }

    private void onConnectivityStatus(final ConnectivityStatus cs) {
        switch (cs) {
        case DISCONNECTED:
            changeIcon(ICON_DISCONNECTED);
            changeStatusLabel(LABEL_DISCONNECTED);
            break;
        case CONNECTED:
            changeIcon(ICON_CONNECTED);
            changeStatusLabel(LABEL_CONNECTED);
            break;
        case CONNECTING:
            changeIcon(ICON_CONNECTING);
            changeStatusLabel(LABEL_CONNECTING);
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
        SwingUtilities.invokeLater(new Runnable() {
            @Override
            public void run() {
                if (SystemUtils.IS_OS_MAC_OSX) {
                    log.info("Customizing image on OSX...");
                    final Image image = newImage(fileName);
                    setImage(image);
                }
            }
        });
    }

    private void changeStatusLabel(final String status) {
        setStatusLabel(status);
    }
}
