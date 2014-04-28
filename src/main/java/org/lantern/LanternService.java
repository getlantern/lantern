package org.lantern;

public interface LanternService extends Shutdownable {

    /**
     * Starts the service. This method blocks until the service has completely 
     * started.
     */
    void init() throws Exception;

}
