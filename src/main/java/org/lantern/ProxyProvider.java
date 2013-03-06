package org.lantern;

import org.lantern.DefaultProxyTracker.ProxyHolder;

/**
 * Interface for the various types of proxies Lantern uses.
 */
public interface ProxyProvider {

    ProxyHolder getLaeProxy();

    //URI getPeerProxy();
    
    ProxyHolder getProxy();
    
    boolean hasProxy();

}
