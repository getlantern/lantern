package org.lantern.event;

import org.lantern.ConnectivityStatus;

public class ConnectivityStatusChangeEvent {

    private final ConnectivityStatus connectivityStatus;

    public ConnectivityStatusChangeEvent(
        final ConnectivityStatus connectivityStatus) {
            this.connectivityStatus = connectivityStatus;
        
    }

    public ConnectivityStatus getConnectivityStatus() {
        return connectivityStatus;
    }
}
