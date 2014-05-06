package org.lantern;


public class ConnectivityChangedEvent {

    private final boolean isConnected;

    public ConnectivityChangedEvent(final boolean nowConnected) {
        this.isConnected = nowConnected;
    }

    public boolean isConnected() {
        return isConnected;
    }

    @Override
    public String toString() {
        return "ConnectivityChangedEvent [isConnected=" + isConnected + "]";
    }

}
