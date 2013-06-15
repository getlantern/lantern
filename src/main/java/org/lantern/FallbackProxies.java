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

    public static void main(String[] args) {
        final FallbackProxies proxies = new FallbackProxies();
        
        proxies.proxies.add(new FallbackProxy("46.137.228.23", 42633));
        proxies.proxies.add(new FallbackProxy("122.248.231.178", 46392));
        proxies.proxies.add(new FallbackProxy("54.254.120.184", 34063));
        proxies.proxies.add(new FallbackProxy("122.248.213.122", 33079));
        proxies.proxies.add(new FallbackProxy("54.251.95.239",40059));
        proxies.proxies.add(new FallbackProxy("54.251.85.66",7279));
        proxies.proxies.add(new FallbackProxy("175.41.163.49",26072));
        proxies.proxies.add(new FallbackProxy("54.251.73.142",47684));
        proxies.proxies.add(new FallbackProxy("175.41.170.222",28631));
        proxies.proxies.add(new FallbackProxy("54.254.122.30",27227));
        final String str = JsonUtils.jsonify(proxies);
        System.err.println(str);
    }
}
