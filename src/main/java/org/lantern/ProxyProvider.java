package org.lantern;


/**
 * Interface for the various types of proxies Lantern uses.
 */
public interface ProxyProvider {

    ProxyHolder getLaeProxy();

    //URI getPeerProxy();
    
    ProxyHolder getProxy();
    
    boolean hasProxy();

}
