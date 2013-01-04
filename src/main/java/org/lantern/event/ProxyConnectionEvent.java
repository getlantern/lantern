package org.lantern.event;

import org.lantern.ConnectivityStatus;

/**
 * Event created when we successfully connect to a proxy.
 */
public class ProxyConnectionEvent {

    private final ConnectivityStatus connectivityStatus;

    public ProxyConnectionEvent(
        final ConnectivityStatus connectivityStatus) {
            this.connectivityStatus = connectivityStatus;
        
    }

    public ConnectivityStatus getConnectivityStatus() {
        return connectivityStatus;
    }
}
