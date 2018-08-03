package org.lantern.proxy;

import io.netty.handler.codec.http.HttpRequest;

import java.util.Collection;
import java.util.Queue;

import org.lantern.ProxyHolder;
import org.lantern.ProxyTracker;
import org.littleshoot.proxy.ChainedProxy;
import org.littleshoot.proxy.ChainedProxyManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * {@link ChainedProxyManager} that uses various downstream proxies to process
 * requests from our local get mode user.
 */
@Singleton
public class DispatchingChainedProxyManager implements ChainedProxyManager {
    private static final Logger LOG = LoggerFactory
            .getLogger(DispatchingChainedProxyManager.class);

    private final ProxyTracker proxyTracker;

    @Inject
    public DispatchingChainedProxyManager(ProxyTracker proxyTracker) {
        this.proxyTracker = proxyTracker;
    }

    @Override
    public void lookupChainedProxies(HttpRequest httpRequest,
            Queue<ChainedProxy> chainedProxies) {
        String host = httpRequest.headers().get("Host");
        Collection<ProxyHolder> proxyHolders = proxyTracker
                .getConnectedProxiesInOrderOfFallbackPreference(host);

        // Add all connected ProxyHolders to our queue of chained proxies
        chainedProxies.addAll(proxyHolders);

        logFallbackOrder(proxyHolders);
    }

    private void logFallbackOrder(Collection<ProxyHolder> proxyHolders) {
        if (LOG.isDebugEnabled()) {
            LOG.debug("Proxy Fallback Order ({} proxies):", proxyHolders.size());
            for (ProxyHolder proxy : proxyHolders) {
                LOG.debug("{} {}", proxy.getJid(), proxy.getFiveTuple());
            }
        }
    }

}