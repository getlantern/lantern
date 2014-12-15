package org.lantern.proxy;

import static org.junit.Assert.*;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;

import org.junit.Test;
import org.lantern.proxy.pt.FlashlightMasquerade;
import org.lantern.proxy.pt.FlashlightProxy;
import org.lantern.state.UDPProxyPriority;

public class ProxyPrioritizerTest {

    @Test
    public void test() throws Exception {
        final List<ProxyHolder> proxies = new ArrayList<ProxyHolder>();
        
        final ProxyHolder flashlight = newFlashlight();
        proxies.add(flashlight);
        final ProxyHolder fallback = newFallback();
        proxies.add(fallback);
        
        final ProxyHolder fallback1 = newFallback();
        proxies.add(fallback1);
        
        final List<ProxyHolder> fallbacks = new ArrayList<ProxyHolder>();
        final List<ProxyHolder> fallbacks1 = new ArrayList<ProxyHolder>();
        final List<ProxyHolder> flashlights = new ArrayList<ProxyHolder>();
        for (int i = 0; i < 100; i++) {
            final ProxyPrioritizer pp = 
                    new ProxyPrioritizer(UDPProxyPriority.LOWER);
            Collections.sort(proxies, pp);
            final ProxyHolder first = proxies.iterator().next();
            if (first == fallback) {
                fallbacks.add(first);
            } else if (first == fallback1) {
                fallbacks1.add(first);
            } else {
                flashlights.add(first);
            }
        }
        assertTrue("No fallbacks selected", fallbacks.size() > 0);
        assertTrue("No fallbacks1 selected", fallbacks1.size() > 0);
        assertTrue("No flashlights selected", flashlights.size() > 0);
    }

    private ProxyHolder newFlashlight() {
        final FlashlightMasquerade masq = 
                new FlashlightMasquerade(new HashMap<String, String>());
        final ProxyInfo info = new FlashlightProxy("test", 1, masq, "", "");
        return new ProxyHolder(null, null, null, info);
    }

    private ProxyHolder newFallback() {
        final ProxyInfo info = new FallbackProxy();
        return new ProxyHolder(null, null, null, info);
    }

}
