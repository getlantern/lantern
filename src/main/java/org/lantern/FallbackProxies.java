package org.lantern;

import java.util.Collection;
import java.util.HashSet;

public class FallbackProxies {
    
    private Collection<FallbackProxy> proxies = new HashSet<FallbackProxy>();
    
    public FallbackProxies() {}

    public Collection<FallbackProxy> getProxies() {
        return proxies;
    }

    public void setProxies(Collection<FallbackProxy> proxies) {
        this.proxies = proxies;
    }
}
