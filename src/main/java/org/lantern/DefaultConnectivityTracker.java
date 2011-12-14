package org.lantern;

import java.util.ArrayList;
import java.util.Collection;

/**
 * Keeps track of the state of Lantern's connectivity.
 */
public class DefaultConnectivityTracker implements ConnectivityTracker {
    
    private ConnectivityStatus connectivityStatus = 
        ConnectivityStatus.DISCONNECTED;
    
    private final Collection<ConnectivityListener> listeners =
        new ArrayList<ConnectivityListener>();

    @Override
    public void addListener(final ConnectivityListener cl) {
        synchronized (listeners) {
            listeners.add(cl);
        }
    }

    @Override
    public void setConnectivityStatus(final ConnectivityStatus ct) {
        if (this.connectivityStatus == ct) {
            return;
        }
        this.connectivityStatus = ct;
        synchronized (listeners) {
            for (final ConnectivityListener cl : listeners) {
                cl.onConnectivityStateChanged(ct);
            }
        }
    }

    @Override
    public ConnectivityStatus getConnectivityStatus() {
        return this.connectivityStatus;
    }
}
