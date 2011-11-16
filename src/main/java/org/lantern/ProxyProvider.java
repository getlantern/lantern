package org.lantern;

import java.net.InetSocketAddress;

/**
 * Interface for the various types of proxies Lantern uses.
 */
public interface ProxyProvider {

    InetSocketAddress getLaeProxy();
    
    //URI getAnonymousProxy();
    
    //URI getPeerProxy();

    InetSocketAddress getProxy();

}
