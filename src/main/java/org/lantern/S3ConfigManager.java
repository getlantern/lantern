package org.lantern;

import java.util.Collection;


public interface S3ConfigManager {

    Collection<FallbackProxy> getFallbackProxies();

    void registerUpdateCallback(Runnable r);
}
