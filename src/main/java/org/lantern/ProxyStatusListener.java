package org.lantern;

import java.net.URI;

import org.lantern.DefaultProxyTracker.ProxyHolder;

/**
 * Listener for the state of proxies.
 */
public interface ProxyStatusListener {

    /**
     * Called when a connection to a proxy fails.
     * 
     * @param proxyAddress The address of the proxy.
     */
    void onCouldNotConnect(ProxyHolder proxyAddress);

    void onCouldNotConnectToPeer(URI peerUri);

    void onError(URI peerUri);

    void onCouldNotConnectToLae(ProxyHolder proxyAddress);

}
