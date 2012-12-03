package org.lantern;

import java.net.InetSocketAddress;

/**
 * Interface for the various types of proxies Lantern uses.
 */
public interface ProxyProvider {

    InetSocketAddress getLaeProxy();

    // Do not remove these -- required for tests.
    //PeerProxyManager getAnonymousPeerProxyManager();
    //PeerProxyManager getTrustedPeerProxyManager();

    //URI getAnonymousProxy();    
    //URI getPeerProxy();

    InetSocketAddress getProxy();

}
