package org.lantern;

import static org.lantern.state.Peer.Type.*;
import static org.littleshoot.util.FiveTuple.Protocol.*;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.ReentrantLock;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.lantern.event.Events;
import org.lantern.event.ProxyConnectionEvent;
import org.lantern.event.ResetEvent;
import org.lantern.state.Model;
import org.lantern.state.Peer;
import org.lantern.state.Peer.Type;
import org.lantern.state.SyncPath;
import org.lantern.util.Threads;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.FiveTuple.Protocol;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class for keeping track of all proxies we know about.
 */
@Singleton
public class DefaultProxyTracker implements ProxyTracker {
    private static final FiveTuple EMPTY_UDP_TUPLE = new FiveTuple(null, null,
            UDP);

    private static final Logger LOG = LoggerFactory
            .getLogger(DefaultProxyTracker.class);

    private final ProxyPrioritizer PROXY_PRIORITIZER = new ProxyPrioritizer();

    /**
     * Holds all proxies.
     */
    private final Set<ProxyHolder> proxies = Collections
            .synchronizedSet(new HashSet<ProxyHolder>());

    private final Model model;

    private final PeerFactory peerFactory;

    private final ScheduledExecutorService proxyRetryService = Threads
            .newScheduledThreadPool("Proxy-Retry");

    private final LanternTrustStore lanternTrustStore;

    /**
     * This is a lock for when we need to block on retrieving a TCP proxy, such
     * as when we need to access a blocked site over HTTP during initial setup.
     */
    private final ReentrantLock tcpProxyLock = new ReentrantLock();

    /**
     * Condition for when there are no proxies -- threads needing proxies wait
     * on this until proxies are available within the timeout or not.
     */
    private final Condition noProxies = this.tcpProxyLock.newCondition();

    @Inject
    public DefaultProxyTracker(final Model model,
            final PeerFactory peerFactory,
            final LanternTrustStore lanternTrustStore) {
        this.model = model;
        this.peerFactory = peerFactory;
        this.lanternTrustStore = lanternTrustStore;

        // Periodically restore timed in proxies
        proxyRetryService.scheduleWithFixedDelay(new Runnable() {
            @Override
            public void run() {
                restoreTimedInProxies();
            }
        }, 100, 100, TimeUnit.MILLISECONDS);

        Events.register(this);
    }

    @Subscribe
    public void onNewS3Config(final S3Config config) {
        LOG.debug("Refreshing fallbacks");
        Set<ProxyHolder> fallbacks = new HashSet<ProxyHolder>();
        for (ProxyHolder p : proxies) {
            if (p.getType() == Type.cloud) {
                LOG.debug("Removing fallback (I may readd it shortly): ",
                        p.getJid());
                fallbacks.add(p);
            }
        }
        proxies.removeAll(fallbacks);
        addFallbackProxies(config);
    }

    @Override
    public void clear() {
        proxies.clear();

        // We need to add the fallback proxy back in.
        addFallbackProxies(this.model.getS3Config());
    }

    @Override
    public void clearPeerProxySet() {
        Iterator<ProxyHolder> it = proxies.iterator();
        while (it.hasNext()) {
            if (it.next().isNatTraversed()) {
                it.remove();
            }
        }
    }

    @Override
    public void addProxy(URI jid) {
        this.addProxy(jid, null);
    }

    @Override
    public void addProxy(URI jid, InetSocketAddress address) {
        // We've seen this in weird cases in the field -- might as well
        // program defensively here.
        InetAddress remoteAddress = null;
        if (address != null) {
            remoteAddress = address.getAddress();
        }
        if (remoteAddress != null) {
            if (remoteAddress.isLoopbackAddress()
                    || remoteAddress.isAnyLocalAddress()) {
                LOG.warn(
                        "Can connect to neither loopback nor 0.0.0.0 address {}",
                        remoteAddress);
                address = null;
            }
        }

        addProxy(jid, address, Type.pc, TCP, null);
    }

    @Override
    public void removeNattedProxy(final URI uri) {
        Iterator<ProxyHolder> it = proxies.iterator();
        while (it.hasNext()) {
            ProxyHolder proxy = it.next();
            if (proxy.getJid().equals(uri) && proxy.isNatTraversed()) {
                LOG.debug("Removing peer by request: {}", uri);
                it.remove();
            }
        }
    }

    @Subscribe
    public void onConnectivityChanged(ConnectivityChangedEvent e) {
        LOG.debug("Got connectivity changed event: {}", e);
        if (e.isConnected()) {
            restoreDeceasedProxies();
        }
    }

    @Override
    public void onCouldNotConnect(final ProxyHolder proxy) {
        // This can happen in several scenarios. First, it can happen if you've
        // actually disconnected from the internet. Second, it can happen if
        // the proxy is blocked. Third, it can happen when the proxy is simply
        // down for some reason.

        // We should remove the proxy here but should certainly keep it on disk
        // so we can try to connect to it in the future.
        LOG.info("COULD NOT CONNECT TO STANDARD PROXY!! Proxy address: {}",
                proxy.getFiveTuple());
        proxy.failedToConnect();
        notifyProxiesSize();
    }

    @Override
    public void onError(final URI peerUri) {
        for (ProxyHolder proxy : proxies) {
            if (proxy.getJid().equals(peerUri)) {
                proxy.failedToConnect();
            }
        }
        notifyProxiesSize();
    }

    @Override
    public boolean hasProxy() {
        return !proxies.isEmpty();
    }

    @Subscribe
    public void onReset(final ResetEvent event) {
        clear();
    }

    @Override
    public void stop() {
        proxyRetryService.shutdownNow();
    }

    @Override
    public Collection<ProxyHolder> getConnectedProxiesInOrderOfFallbackPreference(
            String host) {
        List<ProxyHolder> result = new ArrayList<ProxyHolder>();
        for (ProxyHolder proxy : proxies) {
            if (proxy.isConnected()) {
                if (proxy.getPeer().proxiesHost(host)) {
                    result.add(proxy);
                }
            }
        }
        Collections.sort(result, PROXY_PRIORITIZER);
        return result;
    }

    private void addProxy(URI jid, InetSocketAddress address, Type type,
            Protocol protocol, String lanternAuthToken) {
        boolean natTraversed = address == null || address.getPort() == 0;
        FiveTuple fiveTuple = !natTraversed ? new FiveTuple(null, address,
                protocol)
                : EMPTY_UDP_TUPLE;
        ProxyHolder proxy = new ProxyHolder(this, peerFactory,
                lanternTrustStore, jid, fiveTuple, type, natTraversed,
                lanternAuthToken);
        doAddProxy(jid, proxy);
    }

    private void doAddProxy(final URI jid, final ProxyHolder proxy) {
        LOG.info("Attempting to add proxy {} {}", jid, proxy);

        if (proxies.contains(proxy)) {
            LOG.debug("Proxy already tracked.  Proxies is: {}", proxies);
            return;
        } else {
            LOG.info("Adding proxy {} {}", jid, proxy);
            proxies.add(proxy);
            LOG.info("Proxies is now {}", proxies);
            if (proxy.getType() == Peer.Type.cloud) {
                // Assume cloud proxies to be connected
                successfullyConnectedToProxy(proxy);
            } else {
                // Assume other proxies to not be connected and let the
                // {@link #restoreTimedInProxies()} logic pick it up on its next
                // run
                onCouldNotConnect(proxy);
            }
        }
    }

    private void checkConnectivityToProxy(ProxyHolder proxy) {
        if (proxy.isNatTraversed()) {
            // NAT traversed UDP proxies are currently disabled
            // checkConnectivityToNattedProxy(proxy);
        } else {
            if (proxy.getFiveTuple().getProtocol() == TCP) {
                checkConnectivityToTcpProxy(proxy);
            } else {
                // TODO: need to actually test UDT connectivity somehow
                successfullyConnectedToProxy(proxy);
            }
        }
    }

    private void checkConnectivityToTcpProxy(final ProxyHolder proxy) {
        final Socket sock = new Socket();
        final InetSocketAddress remote = proxy.getFiveTuple()
                .getRemote();
        try {
            sock.connect(remote, 60 * 1000);
            notifyTcpProxyAvailable();
            successfullyConnectedToProxy(proxy);
        } catch (final IOException e) {
            // This can happen if the user has subsequently gone
            // offline, for example.
            LOG.debug("Could not connect to proxy: {}", proxy, e);
            onCouldNotConnect(proxy);

            if (proxy.attemptNatTraversalIfConnectionFailed()) {
                addProxy(proxy.getJid());
            }
        } finally {
            IOUtils.closeQuietly(sock);
        }
    }

    /**
     * Let threads waiting on the first connected TCP proxy know that we now
     * have one.
     */
    private void notifyTcpProxyAvailable() {
        LOG.debug("Got TCP proxy...unlocking");
        this.tcpProxyLock.lock();
        try {
            noProxies.signalAll();
        } finally {
            this.tcpProxyLock.unlock();
        }
    }

    /**
     * Let the world know that we've successfully connected to the proxy.
     * 
     * @param proxy
     */
    private void successfullyConnectedToProxy(ProxyHolder proxy) {
        LOG.debug("Connected to proxy: {}", proxy);
        peerFactory.onOutgoingConnection(proxy.getJid(), proxy.getFiveTuple()
                .getRemote(), proxy.getType());
        proxy.markConnected();

        LOG.debug("Dispatching CONNECTED event");
        Events.asyncEventBus().post(
                new ProxyConnectionEvent(ConnectivityStatus.CONNECTED));

        notifyProxiesSize();
    }

    private void notifyProxiesSize() {
        int numberOfConnectedProxies = 0;
        for (ProxyHolder proxy : proxies) {
            if (proxy.isConnected()) {
                numberOfConnectedProxies += 1;
            }
        }
        model.getConnectivity().setNProxies(numberOfConnectedProxies);
        Events.sync(SyncPath.CONNECTIVITY_NPROXIES, numberOfConnectedProxies);

        if (numberOfConnectedProxies == 0) {
            Events.asyncEventBus().post(
                    new ProxyConnectionEvent(ConnectivityStatus.DISCONNECTED));
        }
    }

    private void restoreTimedInProxies() {
        long now = new Date().getTime();
        for (ProxyHolder proxy : proxies) {
            if (proxy.needsConnectionTest()) {
                if (now > proxy.getRetryTime()) {
                    LOG.debug("Attempting to restore timed-in proxy: {}", proxy);
                    checkConnectivityToProxy(proxy);
                } else {
                    LOG.debug("Proxy not yet ready to retry: {}", proxy);
                    break;
                }
            }
        }
    }

    private void restoreDeceasedProxies() {
        LOG.debug("Checking to restore {} proxies", proxies.size());
        for (ProxyHolder proxy : proxies) {
            if (proxy.needsConnectionTest()) {
                LOG.debug("Attempting to restore deceased proxy: {}", proxy);
                // Proxy may have accumulated a long back-off time while we
                // were offline, so let's reset its failures.
                proxy.resetRetryInterval();
                checkConnectivityToProxy(proxy);
            } else {
                LOG.debug("Proxy does not need a connection test: {}", proxy);
                break;
            }
        }
    }

    private void addFallbackProxies(final S3Config config) {
        if (config == null) {
            LOG.debug("Ignoring null config");
            return;
        }
        LOG.debug("Attempting to add fallback proxies");
        for (final FallbackProxy fp : config.getFallbacks()) {
            addSingleFallbackProxy(fp);
        }
    }

    private void addSingleFallbackProxy(FallbackProxy fallbackProxy) {
        LOG.debug("Attempting to add single fallback proxy");
        final String cert = fallbackProxy.getCert();
        if (StringUtils.isNotBlank(cert)) {
            lanternTrustStore.addCert(cert);
        } else {
            LOG.warn("Fallback with no cert? {}", fallbackProxy);
        }
        final URI uri = LanternUtils.newURI("fallback-" + fallbackProxy.getIp()
                + "@getlantern.org");
        this.peerFactory.addPeer(uri, Type.cloud);
        
        LOG.debug("Adding fallback: {}", fallbackProxy.getIp());
        Protocol protocol = "udp".equalsIgnoreCase(fallbackProxy.getProtocol()) ?
                UDP
                : TCP;
        addProxy(uri, LanternUtils.isa(fallbackProxy.getIp(),
                fallbackProxy.getPort()), Type.cloud, protocol,
                fallbackProxy.getAuth_token());
    }

    /**
     * <p>
     * Prioritizes proxies based on the following rules (highest to lowest):
     * </p>
     * 
     * <ol>
     * <li>Prioritize other Lanterns over fallback proxies</li>
     * <li>Prioritize TCP over UDP</li>
     * <li>Prioritize proxies to whom we have fewer open sockets</li>
     * </ol>
     */
    private class ProxyPrioritizer implements Comparator<ProxyHolder> {
        @Override
        public int compare(ProxyHolder a, ProxyHolder b) {
            // Prioritize other Lanterns over fallback proxies
            Type typeA = a.getType();
            Type typeB = b.getType();
            if (typeA == pc && typeB != pc) {
                return -1;
            } else if (typeB == pc && typeA != pc) {
                return 1;
            }

            // Prioritize TCP over UDP
            int protocolPriority = 0;
            Protocol protocolA = a.getFiveTuple().getProtocol();
            Protocol protocolB = b.getFiveTuple().getProtocol();
            if (protocolA == TCP && protocolB != TCP) {
                protocolPriority = -1;
            } else if (protocolB == TCP && protocolA != TCP) {
                protocolPriority = 1;
            }
            // Adjust protocolPriority based on configured UDP proxy priority
            protocolPriority = model.getSettings().getUdpProxyPriority()
                    .adjustComparisonResult(protocolPriority);
            if (protocolPriority != 0) {
                return protocolPriority;
            }

            // Prioritize based on least number of open sockets
            long numberOfSocketsA = a.getPeer().getNSockets();
            long numberOfSocketsB = b.getPeer().getNSockets();
            if (numberOfSocketsA < numberOfSocketsB) {
                return -1;
            } else if (numberOfSocketsB > numberOfSocketsA) {
                return 1;
            } else {
                return 0;
            }
        }
    }

    @Override
    public void start() throws Exception {
        // Do nothing.
    }
}
