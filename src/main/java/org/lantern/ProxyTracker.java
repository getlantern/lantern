package org.lantern;

import java.net.InetSocketAddress;
import java.net.URI;
import java.util.Collection;

/**
 * Interface for all classes that keep track of proxies.
 */
public interface ProxyTracker extends LanternService {

    void clear();

    void clearPeerProxySet();

    /**
     * Adds a proxy for the given JabberID at the given address. If the
     * <code>address</code> isn't given, we will attempt to do a NAT Traversal
     * to find an address for the given Jabber ID.
     * 
     * @param jid
     *            Jabber ID for the peer
     * @param address
     *            (optional) address at which we expect the proxy to be
     *            listening
     */
    void addProxy(URI jid, InetSocketAddress address);

    /**
     * Adds a proxy for the given JabberID at an unknown address. We will
     * attempt to do a NAT Traversal to find an address for the given Jabber ID.
     * 
     * @param jid
     */
    void addProxy(URI jid);

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
     * @param host the host to which we're trying to connect
     * @return
     */
    Collection<ProxyHolder> getConnectedProxiesInOrderOfFallbackPreference(String host);

    /**
     * Called when a connection to a proxy fails.
     * 
     * @param proxyAddress
     *            The address of the proxy.
     */
    void onCouldNotConnect(ProxyHolder proxyAddress);

    void onError(URI peerUri);

}
