package org.lantern;

/**
 * Interface to the state of Lantern's connection.
 */
public interface ConnectivityTracker {

    ConnectivityStatus getConnectivityStatus();
}
