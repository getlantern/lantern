package org.lantern;

public interface Shutdownable {

    /**
     * Stops the service. This method blocks until the service has completely shut down.
     */
    void stop();
}
