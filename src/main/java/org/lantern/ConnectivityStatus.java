package org.lantern;

/**
 * Enumeration of connectivity statuses.
 */
public enum ConnectivityStatus {

    DISCONNECTED("disconnected"),
    CONNECTING("connecting"),
    CONNECTED("connected");
    
    private final String status;

    private ConnectivityStatus(final String status) {
        this.status = status;
    }
    
    @Override 
    public String toString() {
        return this.status;
    }
}
