package org.lantern.proxy;

import java.net.URI;
import java.util.Collection;

import org.lantern.Shutdownable;

/**
 * Interface for all classes that keep track of proxies.
 */
public interface ProxyTracker extends Shutdownable {

    void clear();

    void clearPeerProxySet();

    /**
     * Adds a proxy for the given {@link ProxyInfo}. Depending on whether or not
     * there's a mapped address available for the given ProxyInfo, this may
     * result in a NAT traversal.
     * 
     * @param info
     *            information identifying the proxy
     */
    void addProxy(ProxyInfo info);

    void addSingleFallbackProxy(FallbackProxy fp);

    /**
     * Remove the NAT traversed proxy for the peer identified by the given URI.
     * 
     * @param uri
     */
    void removeNattedProxy(URI uri);

    boolean hasProxy();

    /**
     * Return a collection of all connected proxies in order of preference for
     * using them.
     * 
     * @return
     */
    Collection<ProxyHolder> getConnectedProxiesInOrderOfFallbackPreference();

    /**
     * Gets the first proxy in order of fallback preference.
     * 
     * @return
     */
    ProxyHolder firstConnectedTcpProxy();

    /**
     * Called when a connection to a proxy fails.
     * 
     * @param proxyAddress
     *            The address of the proxy.
     */
    void onCouldNotConnect(ProxyHolder proxyAddress);

    void onError(URI peerUri);

    void init();
    
    void start();

}
