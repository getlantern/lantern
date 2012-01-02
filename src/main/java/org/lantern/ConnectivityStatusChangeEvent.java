package org.lantern;

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
