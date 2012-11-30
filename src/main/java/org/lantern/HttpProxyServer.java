package org.lantern;

/**
 * Interface for the top-level proxy server class.
 */
public interface HttpProxyServer extends LanternService {

    void start(boolean localOnly, boolean anyAddress);
    
}
