package org.mg.client;

import java.net.InetSocketAddress;
import java.net.URI;

/**
 * Listener for the state of proxies.
 */
public interface ProxyStatusListener {

    /**
     * Called when a connection to a proxy fails.
     * 
     * @param proxyAddress The address of the proxy.
     */
    void onCouldNotConnect(InetSocketAddress proxyAddress);

    void onCouldNotConnectToPeer(URI peerUri);

    void onError(URI peerUri);

}
