package org.lantern;

/**
 * Interface to the state of Lantern's connection.
 */
public interface ConnectivityTracker {

    void addListener(ConnectivityListener cl);
    
    void setConnectivityStatus(ConnectivityStatus ct);
    
    ConnectivityStatus getConnectivityStatus();
}
