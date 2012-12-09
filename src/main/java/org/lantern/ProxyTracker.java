package org.lantern;

import java.net.URI;

/**
 * Interface for all classes that keep track of proxies.
 */
public interface ProxyTracker extends ProxyStatusListener, ProxyProvider{

    boolean isEmpty();

    void clear();

    void clearPeerProxySet();

    boolean addPeerProxy(URI peerUri);

    void addLaeProxy(String cur);

    void addGeneralProxy(String cur);

    void removePeer(URI uri);

}
