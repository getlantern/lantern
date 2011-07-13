package org.lantern;

import java.net.InetSocketAddress;
import java.net.URI;

/**
 * Interface for the various types of proxies Lantern uses.
 */
public interface ProxyProvider {

    InetSocketAddress getLaeProxy();
    
    URI getAnonymousProxy();
    
    URI getPeerProxy();

    InetSocketAddress getProxy();

}
