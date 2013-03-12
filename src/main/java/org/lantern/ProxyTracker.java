package org.lantern;

import java.net.InetSocketAddress;
import java.net.URI;

/**
 * Interface for all classes that keep track of proxies.
 */
public interface ProxyTracker extends ProxyStatusListener, ProxyProvider, 
    LanternService{

    boolean isEmpty();

    void clear();

    void clearPeerProxySet();

    void addLaeProxy(String cur);

    void addProxy(String hostPort);
    
    void addProxy(InetSocketAddress iae);
    
    void addJidProxy(URI jid);
    
    void removePeer(URI uri);


}
