package org.lantern;

import java.util.Collection;


public interface S3ConfigManager {

    Collection<FallbackProxy> getFallbackProxies();

    String getControllerId();

    void registerUpdateCallback(Runnable r);
}
