package org.lantern;

import org.lantern.event.Events;

import com.google.common.eventbus.Subscribe;

/**
 * The base class for system tray items, containing code shared among all system
 * trays
 *
 */
public abstract class BaseSystemTray implements SystemTray {
    // XXX i18n
    public final static String LABEL_DISCONNECTED = "Lantern: Not connected";
    public final static String LABEL_CONNECTING = "Lantern: Connecting...";
    public final static String LABEL_CONNECTED = "Lantern: Connected";

    // could be changed to red/yellow/green
    final static String ICON_DISCONNECTED = "16off.png";
    final static String ICON_CONNECTING = "16off.png";
    final static String ICON_CONNECTED = "16on.png";

    public BaseSystemTray() {
        super();
        Events.register(this);
    }

    @Subscribe
    public void onConnectivityStatus(final ConnectivityStatus cs) {
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

    private void changeIcon(final String icon, final String label) {
        changeIcon(icon);
        changeLabel(label);
    }

    protected abstract void changeIcon(final String icon);

    protected abstract void changeLabel(final String label);

    @Subscribe
    public void onConnectivityChanged(ConnectivityChangedEvent e) {
        if (e.isConnected()) {
            onConnectivityStatus(ConnectivityStatus.CONNECTED);
        } else {
            onConnectivityStatus(ConnectivityStatus.DISCONNECTED);
        }
    }
}