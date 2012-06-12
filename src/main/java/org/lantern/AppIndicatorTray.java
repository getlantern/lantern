package org.lantern;

import java.io.File;
import java.util.Map;

import org.lantern.linux.AppIndicator;
import org.lantern.linux.Glib;
import org.lantern.linux.Gobject;
import org.lantern.linux.Gtk;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.sun.jna.Native;
import com.sun.jna.Pointer;


/**
 * Class for handling all system tray interactions.
 * specialization for using app indicators in ubuntu. 
 */
public class AppIndicatorTray implements SystemTray {

    private static final Logger LOG = LoggerFactory.getLogger(AppIndicatorTray.class);

    private final static String LABEL_DISCONNECTED = "Lantern: Not connected";
    private final static String LABEL_CONNECTING = "Lantern: Connecting...";
    private final static String LABEL_CONNECTED = "Lantern: Connected";
    private final static String LABEL_DISCONNECTING = "Lantern: Disconnecting...";
    
    // could be changed to red/yellow/green
    private final static String ICON_DISCONNECTED  = "16off.png";
    private final static String ICON_CONNECTING    = "16off.png"; 
    private final static String ICON_CONNECTED     = "16on.png";
    private final static String ICON_DISCONNECTING = "16off.png"; 

    private static Glib libglib = null;
    private static Gobject libgobject = null;
    private static Gtk libgtk = null;

    private static AppIndicator libappindicator = null;
    static {
        try {
            libappindicator = (AppIndicator) Native.loadLibrary("appindicator", AppIndicator.class);
            libgtk = (Gtk) Native.loadLibrary("gtk-x11-2.0", Gtk.class);
            libgobject = (Gobject) Native.loadLibrary("gobject-2.0", Gobject.class);
            libglib = (Glib) Native.loadLibrary("glib-2.0", Glib.class);
            //libunique = (Unique) Native.loadLibrary("unique-3.0", Unique.class);
        }
        catch (Throwable ex) {
            LOG.debug("no supported version of appindicator libs found: {}", ex.getMessage());
        }
    }

    public static boolean isSupported() {
        return (libglib != null && libgtk != null && libappindicator != null);
    }


    public interface FailureCallback {
        public void createTrayFailed();
    };

    private AppIndicator.AppIndicatorInstanceStruct appIndicator;
    private Pointer menu;
    
    private Pointer connectionStatusItem;
    private Pointer dashboardItem;
    private Pointer updateItem;
    private Pointer quitItem;

    // need to hang on to these to prevent gc
    private Gobject.GCallback connectionStatusItemCallback;
    private Gobject.GCallback dashboardItemCallback;
    private Gobject.GCallback updateItemCallback;
    private Gobject.GCallback quitItemCallback;

    FailureCallback _failureCallback = null;

    private Map<String, Object> updateData;

    public AppIndicatorTray() {        
    }

    public AppIndicatorTray(FailureCallback fbc) {
        _failureCallback = fbc;
    }

    @Override
    public void createTray() {

        /*uniqueApp = libunique.unique_app_new("org.lantern.lantern", null);
        if (libunique.unique_app_is_running(uniqueApp)) {
            LOG.error("Already running!");
            System.exit(0);
            // could signal to open dashboard
        }*/
        
        menu = libgtk.gtk_menu_new();
        
        connectionStatusItem = libgtk.gtk_menu_item_new_with_label(LABEL_DISCONNECTED);
        libgtk.gtk_widget_set_sensitive(connectionStatusItem, Gtk.FALSE);
        libgtk.gtk_menu_shell_append(menu, connectionStatusItem);
        libgtk.gtk_widget_show_all(connectionStatusItem);
        
        dashboardItem = libgtk.gtk_menu_item_new_with_label("Open Dashboard");
        dashboardItemCallback = new Gobject.GCallback() {
            @Override
            public void callback(Pointer instance, Pointer data) {
                LOG.debug("openDashboardItem callback called");
                openDashboard();
            }
        };
        libgobject.g_signal_connect_data(dashboardItem, "activate", dashboardItemCallback,null, null, 0);
        libgtk.gtk_menu_shell_append(menu, dashboardItem);
        libgtk.gtk_widget_show_all(dashboardItem);
        
        //updateItem = Gtk.gtk_menu_item_new_with_label();
        
        quitItem = libgtk.gtk_menu_item_new_with_label("Quit");
        quitItemCallback = new Gobject.GCallback() {
            @Override
            public void callback(Pointer instance, Pointer data) {
                LOG.debug("quitItemCallback called");
                quit();
            }
        };
        libgobject.g_signal_connect_data(quitItem, "activate", quitItemCallback,null, null, 0);
        libgtk.gtk_menu_shell_append(menu, quitItem);
        libgtk.gtk_widget_show_all(quitItem);
        
        appIndicator = libappindicator.app_indicator_new(
            "lantern", "indicator-messages-new",
            AppIndicator.CATEGORY_APPLICATION_STATUS);
        
        /* XXX basically a hack -- we should subclass the AppIndicator 
           type and override the fallback entry in the 'vtable', instead we just
           hack the app indicator class itself. Not an issue unless we need other 
           appindicators. 
        */
        AppIndicator.AppIndicatorClassStruct aiclass = 
            new AppIndicator.AppIndicatorClassStruct(appIndicator.parent.g_type_instance.g_class);
        
        AppIndicator.Fallback replacementFallback = new AppIndicator.Fallback() {
            @Override
            public Pointer callback(AppIndicator.AppIndicatorInstanceStruct self) {
                fallback();
                return null;
            }
        };

        aiclass.fallback = replacementFallback;
        aiclass.write();

        libappindicator.app_indicator_set_menu(appIndicator, menu);
        
        changeIcon(ICON_DISCONNECTED, LABEL_DISCONNECTED);
        libappindicator.app_indicator_set_status(appIndicator, AppIndicator.STATUS_ACTIVE);
    
        LanternHub.register(this);
    }

    private String iconPath(final String fileName) {
        final File iconTest = new File(ICON_DISCONNECTED);
        if (iconTest.isFile()) {
            return new File(new File("."), fileName).getAbsolutePath();
        }
        // Running from main line.
        return new File(new File("install/common"), fileName).getAbsolutePath();
    }

    protected void fallback() {
        LOG.debug("Failed to create appindicator system tray.");
        if (_failureCallback != null) {
            _failureCallback.createTrayFailed();
        }
    }

    private void openDashboard() {
        LOG.debug("openDashboard called.");
        LanternHub.jettyLauncher().openBrowserWhenReady();
    }

    private void quit() {
        LOG.debug("quit called.");
        LanternHub.xmppHandler().disconnect();
        LanternHub.jettyLauncher().stop();
        System.exit(0);
    }
    
    @Override
    public void addUpdate(final Map<String, Object> data) { 
        LOG.info("Adding update data: {}", data);
        this.updateData = data;
    }

    @Override
    public boolean isActive() {
        return true;
    }

    @Subscribe
    public void onConnectivityStateChanged(
        final ConnectivityStatusChangeEvent csce) {
        final ConnectivityStatus cs = csce.getConnectivityStatus();
        LOG.info("Got connectivity state changed {}", cs);
        switch (cs) {
        case DISCONNECTED: {
            changeIcon(ICON_DISCONNECTED, LABEL_DISCONNECTED);
            break;
        }
        case CONNECTING: {
            changeIcon(ICON_CONNECTING, LABEL_CONNECTING);
            break;
        }
        case CONNECTED: {
            changeIcon(ICON_CONNECTED, LABEL_CONNECTED);
            break;
        }
        }
    }

    private void changeIcon(final String fileName, final String label) {
        libappindicator.app_indicator_set_icon_full(appIndicator, iconPath(fileName), "Lantern");
        libgtk.gtk_menu_item_set_label(connectionStatusItem, label);
    }
};
