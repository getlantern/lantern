package org.lantern;


/**
 * Keeps track of the state of Lantern's connectivity.
 */
public class DefaultConnectivityTracker implements ConnectivityTracker, 
    ConnectivityListener {
    
    private ConnectivityStatus connectivityStatus = 
        ConnectivityStatus.DISCONNECTED;

    /**
     * Creates a new tracker of connectivity.
     */
    public DefaultConnectivityTracker() {
        LanternHub.notifier().addConnectivityListener(this);
    }

    @Override
    public ConnectivityStatus getConnectivityStatus() {
        return this.connectivityStatus;
    }
    @Override
    public void onConnectivityStateChanged(final ConnectivityStatus ct) {
        this.connectivityStatus = ct;
    }
}
