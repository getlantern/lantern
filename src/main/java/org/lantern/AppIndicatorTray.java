package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.InputStream;
import java.util.Map;

import org.apache.commons.lang.SystemUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

import org.lantern.linux.AppIndicator;
import org.lantern.linux.Glib;
import org.lantern.linux.Gobject;
import org.lantern.linux.Gtk;
import org.lantern.linux.Unique;

import com.sun.jna.Callback;
import com.sun.jna.Library;
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
    //private static Unique libunique = null;
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
    
    private Pointer mainContext;
    private Pointer mainLoop;

    private Pointer uniqueApp;
    private Pointer appIndicator;
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
        
        dashboardItem = libgtk.gtk_menu_item_new_with_label("Open Dashboard");
        dashboardItemCallback = new Gobject.GCallback() {
            @Override
            public void callback(Pointer instance, Pointer data) {
                LOG.debug("openDashboardItem callback called");
                openDashboard();
            }
        };
        libgobject.g_signal_connect_data(dashboardItem, "activate", dashboardItemCallback,null, null, 0);
        libgtk.gtk_widget_set_sensitive(connectionStatusItem, Gtk.TRUE);
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
        libgtk.gtk_widget_set_sensitive(quitItem, Gtk.TRUE);
        libgtk.gtk_menu_shell_append(menu, quitItem);
        libgtk.gtk_widget_show_all(quitItem);
        
        appIndicator = libappindicator.app_indicator_new(
            "lantern", "indicator-messages-new",
            AppIndicator.CATEGORY_APPLICATION_STATUS);
        libappindicator.app_indicator_set_menu(appIndicator, menu);
        libappindicator.app_indicator_set_status(appIndicator, libappindicator.STATUS_ACTIVE);
    }

    private void openDashboard() {
        LOG.debug("openDashboard called.");
    }

    private void quit() {
        LOG.debug("quit called.");
    }
    
    @Override
    public void addUpdate(Map<String, String> updateData) {  
    }

};