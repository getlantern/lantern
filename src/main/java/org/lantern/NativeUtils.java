package org.lantern;

import java.awt.Dimension;
import java.awt.Image;
import java.awt.PopupMenu;
import java.lang.reflect.Constructor;

import org.apache.commons.lang.SystemUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Utilities for native calls.
 */
public class NativeUtils
    {
    private static final Logger LOG = 
        LoggerFactory.getLogger(NativeUtils.class);
    
    /**
     * Opens the specified URI using the native file system.  Currently only
     * HTTP URIs are officially supported.
     * 
     * @param uri The URI to open.
     * @return The Process started, or <code>null</code> if there was an
     * error.
     */
    public static Process openUri(final String uri) {
        if (SystemUtils.IS_OS_MAC_OSX) {
            return openSiteMac(uri);
        } else if (SystemUtils.IS_OS_WINDOWS) {
            return openSiteWindows(uri);
        }

        return null;
    }

    private static Process openSiteMac(final String siteUrl) {
        return exec("open", siteUrl);
    }

    private static Process openSiteWindows(final String siteUrl) {
        return exec("cmd.exe", "/C", "start", siteUrl);
    }

    private static Process exec(final String... cmds) {
        final ProcessBuilder pb = new ProcessBuilder(cmds);
        try {
            return pb.start();
        } catch (final Exception e) {
            LOG.error("Could not open site", e);
        }
        return null;
    }

    /**
     * Adds a tray icon using reflection.  This succeeds if the underlying 
     * JVM is 1.6 and supports the system tray, failing otherwise.
     * 
     * @param image The image to use for the system tray icon.
     * @param name The name of the system tray item.
     * @param popup The popup menu to display when someone clicks on the tray.
     */
    public static Dimension getTrayIconSize() {
        final Class[] trayIconArgTypes = new Class[] { java.awt.Image.class,
                java.lang.String.class, java.awt.PopupMenu.class };
        try {

            final Class trayClass = Class.forName("java.awt.SystemTray");
            final Object tray = trayClass.getDeclaredMethod("getSystemTray")
                    .invoke(null);

            final Dimension dim = (Dimension) trayClass.getDeclaredMethod(
                    "getTrayIconSize").invoke(tray);
            return dim;
        } catch (final Exception e) {
            LOG.warn("Reflection error", e);
            return null;
        }
    }
    
    /**
     * Adds a tray icon using reflection.  This succeeds if the underlying 
     * JVM is 1.6 and supports the system tray, failing otherwise.
     * 
     * @param image The image to use for the system tray icon.
     * @param name The name of the system tray item.
     * @param popup The popup menu to display when someone clicks on the tray.
     */
    public static void addTray(final Image image, final String name,
            final PopupMenu popup) {
        final Class[] trayIconArgTypes = new Class[] { java.awt.Image.class,
                java.lang.String.class, java.awt.PopupMenu.class };
        try {
            final Class trayIconClass = Class.forName("java.awt.TrayIcon");
            final Constructor trayIconConstructor = trayIconClass
                    .getConstructor(trayIconArgTypes);
            final Object trayIcon = trayIconConstructor.newInstance(image,
                    name, popup);

            final Class trayClass = Class.forName("java.awt.SystemTray");
            final Object obj = trayClass.getDeclaredMethod("getSystemTray")
                    .invoke(null);

            final Class[] trayAddArgTypes = new Class[] { trayIconClass };
            trayClass.getDeclaredMethod("add", trayAddArgTypes).invoke(obj,
                    trayIcon);
        } catch (final Exception e) {
            LOG.warn("Reflection error", e);
        }
    }

    /**
     * Uses reflection to determine whether or not this operating system and
     * java version supports the system tray.
     * 
     * @return <code>true</code> if it supports the tray, otherwise 
     * <code>false</code>.
     */
    public static boolean supportsTray() {
        try {
            final Class trayClass = Class.forName("java.awt.SystemTray");
            final Boolean bool = (Boolean) trayClass.getDeclaredMethod(
                    "isSupported").invoke(null);
            return bool.booleanValue();
        } catch (final Exception e) {
            LOG.warn("Reflection error", e);
            return false;
        }
    }
}
