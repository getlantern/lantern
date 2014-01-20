package org.lantern;

import java.util.Collection;
import java.util.ArrayList;


public class MockS3ConfigManager implements S3ConfigManager {
    public Collection<FallbackProxy> getFallbackProxies() {
        return new ArrayList<FallbackProxy>();
    }
    public void registerUpdateCallback(Runnable r) {}
}
