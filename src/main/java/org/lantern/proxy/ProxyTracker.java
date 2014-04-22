package org.lantern.proxy;

import java.net.URI;
import java.util.Collection;

import org.lantern.LanternService;

/**
 * Interface for all classes that keep track of proxies.
 */
public interface ProxyTracker extends LanternService {

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
     * @param upstreamPort
     *            - the port of the upstream server to which we want to proxy,
     *            used to determine which proxies are eligible to be returned
     * @return
     */
    Collection<ProxyHolder> getConnectedProxiesInOrderOfFallbackPreference(
            int upstreamPort);

    /**
     * Gets the first proxy in order of fallback preference.
     * 
     * @param upstreamPort
     *            - the port of the upstream server to which we want to proxy,
     *            used to determine which proxies are eligible to be returned
     * @return
     */
    ProxyHolder firstConnectedTcpProxy(int upstreamPort);

    /**
     * Called when a connection to a proxy fails.
     * 
     * @param proxyAddress
     *            The address of the proxy.
     */
    void onCouldNotConnect(ProxyHolder proxyAddress);

    void onError(URI peerUri);

}
