package org.lantern;

/**
 * Interface for classes that listen to proxy state.
 */
public interface ProxyListener {

    void onProxying(boolean proxying);
}
