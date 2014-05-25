package org.lantern.proxy;

import io.netty.handler.codec.http.HttpHeaders;
import io.netty.handler.codec.http.HttpRequest;

import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Queue;
import java.util.Set;

import org.apache.commons.lang3.StringUtils;
import org.lantern.LanternUtils;
import org.lantern.loggly.Loggly;
import org.littleshoot.proxy.ChainedProxy;
import org.littleshoot.proxy.ChainedProxyAdapter;
import org.littleshoot.proxy.ChainedProxyManager;
import org.littleshoot.proxy.impl.ProxyUtils;
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
    
    private static final Set<String> HOSTS_ALLOWING_DIRECT_CONNECTION = new HashSet<String>();
    
    static {
        HOSTS_ALLOWING_DIRECT_CONNECTION.add(Loggly.LOGGLY_HOST);
    }

    private final ProxyTracker proxyTracker;

    @Inject
    public DispatchingChainedProxyManager(ProxyTracker proxyTracker) {
        this.proxyTracker = proxyTracker;
    }

    @Override
    public void lookupChainedProxies(HttpRequest httpRequest,
            Queue<ChainedProxy> chainedProxies) {
        int upstreamPort = identifyUpstreamPort(httpRequest);
        Collection<ProxyHolder> proxyHolders = proxyTracker
                .getConnectedProxiesInOrderOfFallbackPreference(upstreamPort);

        // Add all connected ProxyHolders to our queue of chained proxies
        chainedProxies.addAll(proxyHolders);
        
        // Support falling back to direct connections for selected hosts
        String host = LanternUtils.hostAndPortFrom(httpRequest)[0];
        if (HOSTS_ALLOWING_DIRECT_CONNECTION.contains(host)) {
            LOG.debug("Supporting falling back to direct connection for host: {}", host);
            chainedProxies.add(ChainedProxyAdapter.FALLBACK_TO_DIRECT_CONNECTION);
        }

        logFallbackOrder(upstreamPort, proxyHolders);
    }

    private void logFallbackOrder(int upstreamPort, Collection<ProxyHolder> proxyHolders) {
        if (LOG.isDebugEnabled()) {
            LOG.debug("Proxy Fallback Order for port {} ({} proxies):", upstreamPort, proxyHolders.size());
            for (ProxyHolder proxy : proxyHolders) {
                LOG.debug("{} {}", proxy.getJid(), proxy.getFiveTuple());
            }
        }
    }

    private int identifyUpstreamPort(HttpRequest httpRequest) {
        String hostAndPort = ProxyUtils.parseHostAndPort(httpRequest);
        if (StringUtils.isBlank(hostAndPort)) {
            List<String> hosts = httpRequest.headers().getAll(
                    HttpHeaders.Names.HOST);
            if (hosts != null && !hosts.isEmpty()) {
                hostAndPort = hosts.get(0);
            }
        }

        String[] parts = hostAndPort.split(":");
        return parts.length == 2 ? Integer.parseInt(parts[1]) : 80;
    }
}