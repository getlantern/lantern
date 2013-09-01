package org.lantern;

import java.util.Collection;

/**
 * Interface for the various types of proxies Lantern uses.
 */
public interface ProxyProvider {

    ProxyHolder getProxy();

    ProxyHolder getJidProxy();

    boolean hasProxy();

    /**
     * Return a collection of all proxies in order of preference for using them.
     * 
     * @return
     */
    Collection<ProxyHolder> getAllProxiesInOrderOfFallbackPreference();

}
