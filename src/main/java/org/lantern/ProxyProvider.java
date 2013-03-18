package org.lantern;


/**
 * Interface for the various types of proxies Lantern uses.
 */
public interface ProxyProvider {

    ProxyHolder getLaeProxy();

    ProxyHolder getProxy();
    
    ProxyHolder getJidProxy();
    
    boolean hasProxy();

}
