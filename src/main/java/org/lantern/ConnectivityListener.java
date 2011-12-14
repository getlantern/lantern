package org.lantern;

/**
 * Interface for classes that listen to changes in Lantern's connection status.
 */
public interface ConnectivityListener {

    void onConnectivityStateChanged(ConnectivityStatus ct);
}
