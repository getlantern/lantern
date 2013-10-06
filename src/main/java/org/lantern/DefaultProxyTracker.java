package org.lantern;

import static org.lantern.state.Peer.Type.pc;
import static org.littleshoot.util.FiveTuple.Protocol.TCP;
import static org.littleshoot.util.FiveTuple.Protocol.UDP;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.ReentrantLock;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.SystemUtils;
import org.codehaus.jackson.map.ObjectMapper;
import org.lantern.event.Events;
import org.lantern.event.ModeChangedEvent;
import org.lantern.event.ProxyConnectionEvent;
import org.lantern.event.ResetEvent;
import org.lantern.state.Mode;
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
import com.google.common.io.Files;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class for keeping track of all proxies we know about.
 */
@Singleton
public class DefaultProxyTracker implements ProxyTracker {
    private static final long NAT_TRAVERSAL_INITIAL_DELAY = 5000;

    private final ProxyPrioritizer PROXY_PRIORITIZER = new ProxyPrioritizer();

    private static final Logger LOG = LoggerFactory
            .getLogger(DefaultProxyTracker.class);

    private final ExecutorService p2pSocketThreadPool =
            Threads.newCachedThreadPool("P2P-Socket-Creation-Thread-");

    /**
     * Holds all proxies keyed to their {@link FiveTuple}.
     */
    private final Map<FiveTuple, ProxyHolder> proxies =
            new ConcurrentHashMap<FiveTuple, ProxyHolder>();
    
    /**
     * Holds the times at which a given JID should next be NAT traversed. We use
     * this to implement a back-off strategy that keeps us from too frequently
     * trying to NAT traverse to the same peers.
     */
    private final Map<URI, ScheduledNatTraversal> natTraversalSchedule =
            new ConcurrentHashMap<URI, ScheduledNatTraversal>();

    private final Model model;

    private final PeerFactory peerFactory;

    /**
     * Thread pool for checking connections to proxies -- otherwise these can
     * hold up the XMPP processing thread or any other calling thread.
     */
    private final ExecutorService proxyCheckThreadPool =
            Threads.newCachedThreadPool("Proxy-Connection-Check-Pool-");

    private final XmppHandler xmppHandler;

    private final AtomicBoolean proxiesPopulated = new AtomicBoolean(false);

    private String fallbackServerHost;

    private int fallbackServerPort;

    private final ScheduledExecutorService proxyRetryService = Threads
            .newSingleThreadedScheduledExecutor("Proxy-Retry");

    private final LanternTrustStore lanternTrustStore;
    
    /**
     * This is a lock for when we need to block on retrieving a TCP proxy,
     * such as when we need to access a blocked site over HTTP during initial 
     * setup.
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
            final XmppHandler xmppHandler,
            final LanternTrustStore lanternTrustStore) {
        this.model = model;
        this.peerFactory = peerFactory;
        this.xmppHandler = xmppHandler;
        this.lanternTrustStore = lanternTrustStore;

        // Periodically restore timed in proxies
        proxyRetryService.scheduleWithFixedDelay(new Runnable() {
            @Override
            public void run() {
                restoreTimedInProxies();
            }
        }, 10000, 4000, TimeUnit.MILLISECONDS);

        Events.register(this);
    }

    @Override
    public void start() {
        if (this.model.getSettings().getMode() == Mode.get) {
            prepopulateProxies();
        } else {
            LOG.debug("Not adding proxies in give mode...");
        }
    }

    @Override
    public void clear() {
        proxies.clear();

        // We need to add the fallback proxy back in.
        addFallbackProxies();
    }

    @Override
    public void clearPeerProxySet() {
        Iterator<FiveTuple> it = proxies.keySet().iterator();
        while (it.hasNext()) {
            if (it.next().getProtocol() == UDP) {
                it.remove();
            }
        }
    }

    @Override
    public void addProxy(URI jid, InetSocketAddress address) {
        addProxy(jid, address, Type.pc);
    }

    @Override
    public void addProxy(URI jid) {
        this.addProxy(jid, (ProxyHolder) null);
    }

    private void addProxy(URI jid, InetSocketAddress address, Type type) {
        boolean canAddAsTCP = address != null && address.getPort() > 0
                && this.model.getSettings().isTcp();
        addProxy(jid, canAddAsTCP ? new ProxyHolder(this, peerFactory,
                lanternTrustStore, jid, address, type) : null);
    }

    private void addProxy(URI jid, ProxyHolder proxyHolder) {
        if (proxyHolder != null) {
            addTcpProxy(jid, proxyHolder, true);
        } else {
            addNattedProxy(jid, true);
        }
    }

    /**
     * Attempts to add this proxy as a proxy using a known TCP port.
     * 
     * @param jid
     * @param ph
     * @param allowFallbackToNatTTraversal
     */
    private void addTcpProxy(final URI jid, final ProxyHolder ph,
            final boolean allowFallbackToNatTTraversal) {
        LOG.info("Adding TCP proxy {} {}", jid, ph);

        // We've seen this in weird cases in the field -- might as well
        // program defensively here.
        InetAddress remoteAddress = ph.getFiveTuple().getRemote().getAddress();
        if (remoteAddress.isLoopbackAddress()
                || remoteAddress.isAnyLocalAddress()) {
            LOG.warn("Can connect to neither loopback nor 0.0.0.0 address {}",
                    remoteAddress);
            return;
        }

        proxyCheckThreadPool.submit(new Runnable() {

            @Override
            public void run() {
                final Socket sock = new Socket();
                final InetSocketAddress remote = ph.getFiveTuple().getRemote();
                try {
                    sock.connect(remote, 60 * 1000);

                    if (putTcpProxy(ph) == null) {
                        LOG.debug(
                                "Added connected TCP proxy.  Proxies is now {}",
                                proxies);
                        peerFactory.onOutgoingConnection(jid, remote,
                                ph.getType());
                    }

                    ph.resetFailures();
                    LOG.debug("Dispatching CONNECTED event");
                    Events.asyncEventBus().post(
                            new ProxyConnectionEvent(
                                    ConnectivityStatus.CONNECTED));
                } catch (final IOException e) {
                    // This can happen if the user has subsequently gone
                    // offline, for example.
                    LOG.debug("Could not connect to {} {}", jid, ph, e);
                    onCouldNotConnect(ph);

                    if (allowFallbackToNatTTraversal) {
                        // Try adding the proxy by it's JID! This can happen,
                        // for example, if we get a bogus port mapping.
                        addNattedProxy(jid, true);
                    }
                } finally {
                    IOUtils.closeQuietly(sock);
                }
            }

        });
    }
    
    private ProxyHolder putTcpProxy(final ProxyHolder ph) {
        LOG.debug("Got TCP proxy...unlocking");
        final ProxyHolder holder = proxies.put(ph.getFiveTuple(), ph);
        this.tcpProxyLock.lock();
        try {
            noProxies.signalAll();
        } finally {
            this.tcpProxyLock.unlock();
        }
        return holder;
    }

    /**
     * Attempts to do a NAT traversal to obtain an available UDP port for the
     * given jid and then adds a proxy for that port.
     * 
     * @param jid
     * @param adhereToSchedule
     *            whether or not to adhere to the schedule set in
     *            {@link #natTraversalSchedule}
     */
    private void addNattedProxy(final URI jid,
            final boolean adhereToSchedule) {
        LOG.debug("Considering NAT traversal to proxy for: {}", jid);
        final HashMap<URI, AtomicInteger> peerFailureCount =
                new HashMap<URI, AtomicInteger>();

        if (hasConnectedNatTraversedProxy(jid)) {
            LOG.debug(
                    "Already have connected NAT traversed proxy for {}, declining to add",
                    jid);
            return;
        }

        if (adhereToSchedule) {
            if (!scheduleAllowsNatTraversal(jid)) {
                LOG.debug(
                        "Skipping NAT traversal for {} before scheduled time",
                        jid);
                return;
            }
        }

        p2pSocketThreadPool.submit(new Runnable() {
            @Override
            public void run() {
                // TODO: In the past we created a bunch of connections here -
                // a socket pool -- to avoid dealing with connection time
                // delays. We should probably do that again!.
                try {
                    LOG.debug("Opening outgoing peer...");
                    final FiveTuple tuple = LanternUtils.openOutgoingPeer(
                            jid, xmppHandler.getP2PClient(),
                            peerFailureCount);
                    LOG.debug("Got tuple and adding it for peer: {}", jid);

                    final InetSocketAddress remote = tuple.getRemote();
                    final ProxyHolder ph =
                            new ProxyHolder(DefaultProxyTracker.this,
                                    peerFactory, lanternTrustStore,
                                    jid, tuple, Type.pc);

                    peerFactory.onOutgoingConnection(jid, remote, Type.pc);

                    proxies.put(ph.getFiveTuple(), ph);

                    resetNatTraversalScheduleFor(jid);

                    Events.eventBus().post(
                            new ProxyConnectionEvent(
                                    ConnectivityStatus.CONNECTED));

                } catch (final IOException e) {
                    LOG.info("Could not create peer socket", e);
                    scheduleNextAllowedNatTraversalFor(jid);
                }
            }
        });
    }

    private boolean scheduleAllowsNatTraversal(URI jid) {
        synchronized (natTraversalSchedule) {
            ScheduledNatTraversal scheduled = natTraversalSchedule.get(jid);
            return scheduled == null || scheduled.scheduledTime <= System
                    .currentTimeMillis();
        }
    }

    private void resetNatTraversalScheduleFor(URI jid) {
        synchronized (natTraversalSchedule) {
            natTraversalSchedule.remove(jid);
        }
    }

    private void scheduleNextAllowedNatTraversalFor(URI jid) {
        synchronized (natTraversalSchedule) {
            ScheduledNatTraversal scheduled = natTraversalSchedule
                    .get(jid);
            ScheduledNatTraversal nextScheduled;
            if (scheduled == null) {
                nextScheduled = new ScheduledNatTraversal(
                        NAT_TRAVERSAL_INITIAL_DELAY);
            } else {
                // Back off by a factor of 2
                nextScheduled = new ScheduledNatTraversal(
                        scheduled.delay * 2);
            }
            natTraversalSchedule.put(jid, nextScheduled);
        }
    }

    private boolean hasConnectedNatTraversedProxy(final URI jid) {
        for (ProxyHolder proxy : proxies.values()) {
            if (proxy.getJid().equals(jid) && proxy.isNatTraversed()
                    && proxy.isConnected()) {
                return true;
            }
        }
        return false;
    }

    @Override
    public void removeNatTraversedProxy(final URI uri) {
        Iterator<ProxyHolder> it = proxies.values().iterator();
        while (it.hasNext()) {
            ProxyHolder proxy = it.next();
            if (proxy.getJid().equals(uri) && proxy.isNatTraversed()) {
                LOG.debug("Removing peer by request: {}", uri);
                it.remove();
            }
        }
    }

    private void restoreTimedInProxies() {
        long now = new Date().getTime();
        for (ProxyHolder proxy : proxies.values()) {
            if (!proxy.isConnected() && now > proxy.getRetryTime()) {
                LOG.debug("Attempting to restore timed-in proxy " + proxy);
                if (proxy.isNatTraversed()) {
                    addNattedProxy(proxy.getJid(), false);
                } else {
                    addTcpProxy(proxy.getJid(), proxy, false);
                }
            } else {
                break;
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

    private void restoreDeceasedProxies() {
        long now = new Date().getTime();
        for (ProxyHolder proxy : proxies.values()) {
            if (!proxy.isConnected()) {
                LOG.debug("Attempting to restore deceased proxy " + proxy);
                addTcpProxy(proxy.getJid(), proxy, false);
            } else {
                break;
            }
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
        proxy.addFailure();
        notifyProxiesSize();
    }

    @Override
    public void onError(final URI peerUri) {
        for (ProxyHolder proxy : proxies.values()) {
            if (proxy.getJid().equals(peerUri)) {
                proxy.addFailure();
            }
        }
        notifyProxiesSize();
    }

    private void notifyProxiesSize() {
        int numberOfConnectedProxies = 0;
        for (ProxyHolder proxy : proxies.values()) {
            if (proxy.isConnected()) {
                numberOfConnectedProxies += 1;
            }
        }
        Events.sync(SyncPath.CONNECTIVITY_NPROXIES, numberOfConnectedProxies);
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

    @Subscribe
    public void onModeChanged(final ModeChangedEvent event) {
        LOG.debug("Received mode changed event: {}", event);
        start();
    }

    @Override
    public Collection<ProxyHolder> getConnectedProxiesInOrderOfFallbackPreference() {
        List<ProxyHolder> result = new ArrayList<ProxyHolder>();
        for (ProxyHolder proxy : proxies.values()) {
            if (proxy.isConnected()) {
                result.add(proxy);
            }
        }
        Collections.sort(result, PROXY_PRIORITIZER);
        return result;
    }
    
    @Override
    public ProxyHolder firstConnectedTcpProxy() {
        for (final ProxyHolder ph : getConnectedProxiesInOrderOfFallbackPreference()) {
            if (ph.getFiveTuple().getProtocol() == Protocol.TCP) {
                return ph;
            }
        }
        return null;
    }
    
    @Override
    public ProxyHolder firstConnectedTcpProxyBlocking() throws InterruptedException {
        LOG.debug("Getting first TCP proxy...");
        final ProxyHolder ph = firstConnectedTcpProxy();
        if (ph != null) {
            LOG.debug("Returning existing proxy...");
            return ph;
        }
        
        this.tcpProxyLock.lock();
        try {
            LOG.debug("Waiting for availability...");
            if (this.proxies.isEmpty()) {
                this.noProxies.await(30, TimeUnit.SECONDS);
            }
            LOG.debug("Out of wait...returning proxy");
            return firstConnectedTcpProxy();
        } finally {
            this.tcpProxyLock.unlock();
        }
        
    }

    private void prepopulateProxies() {
        if (this.model.getSettings().getMode() == Mode.give) {
            LOG.debug("Not loading proxies in give mode");
            return;
        }
        if (this.proxiesPopulated.get()) {
            LOG.debug("Proxies already populated!");
            return;
        }
        this.proxiesPopulated.set(true);
        addFallbackProxies();
        // Add all the stored proxies.
        final Collection<Peer> peers = this.model.getPeers();
        LOG.debug("Proxy set is: {}", peers);
        for (final Peer peer : peers) {
            // Don't use peer proxies since we're not connected to XMPP yet.
            if (peer.isMapped()) {
                final String id = peer.getPeerid();
                if (!id.contains(fallbackServerHost)) {
                    addProxy(LanternUtils.newURI(peer.getPeerid()),
                            new InetSocketAddress(peer.getIp(), peer.getPort()));
                }
            }
        }
    }

    private void addFallbackProxies() {
        parseFallbackProxy();
        addSingleFallbackProxy(fallbackServerHost, fallbackServerPort);

        final File file = new File(SystemUtils.USER_HOME, "fallbacks.json");
        if (!file.isFile()) {
            LOG.info("No fallback proxies in: {}", file.getAbsolutePath());
            return;
        }
        final ObjectMapper om = new ObjectMapper();
        InputStream is = null;

        try {
            is = new FileInputStream(file);
            final String proxy = IOUtils.toString(is);
            final FallbackProxies all = om.readValue(proxy,
                    FallbackProxies.class);
            final Collection<FallbackProxy> proxies = all.getProxies();
            for (final FallbackProxy fp : proxies) {
                LOG.debug("Adding fallback: {}", fp);
                addSingleFallbackProxy(fp.getIp(), fp.getPort());
            }
        } catch (final IOException e) {
            LOG.error("Could not load fallback proxies?");
        }
    }

    private void addSingleFallbackProxy(final String host, final int port) {
        if (this.model.getSettings().isTcp()) {
            final URI uri =
                    LanternUtils.newURI("fallback-" + host + "@getlantern.org");
            final Peer cloud = this.peerFactory.addPeer(uri, Type.cloud);
            cloud.setMode(org.lantern.state.Mode.give);

            LOG.debug("Adding fallback: {}", host);
            addProxy(uri, LanternUtils.isa(host, port), Type.cloud);
        }
    }

    private void parseFallbackProxy() {
        final File file =
                new File(LanternClientConstants.CONFIG_DIR, "fallback.json");
        if (!file.isFile()) {
            try {
                copyFallback();
            } catch (final IOException e) {
                LOG.error("Could not copy fallback?", e);
            }
        } else {
            LOG.debug("Fallback file already exists!");
        }
        if (!file.isFile()) {
            LOG.error("No fallback proxy to load!");
            return;
        }

        final ObjectMapper om = new ObjectMapper();
        InputStream is = null;
        try {
            is = new FileInputStream(file);
            final String proxy = IOUtils.toString(is);
            final FallbackProxy fp = om.readValue(proxy, FallbackProxy.class);

            fallbackServerHost = fp.getIp();
            fallbackServerPort = fp.getPort();
            LOG.debug("Set fallback proxy to {}", fallbackServerHost);
        } catch (final IOException e) {
            LOG.error("Could not load fallback", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
    }

    private void copyFallback() throws IOException {
        LOG.debug("Copying fallback file");
        final File from;

        final File cur =
                new File(new File(SystemUtils.USER_DIR), "fallback.json");
        if (cur.isFile()) {
            from = cur;
        } else {
            LOG.debug("No fallback proxy found in home - checking cur...");
            final File home = new File(new File(SystemUtils.USER_HOME),
                    "fallback.json");
            if (home.isFile()) {
                from = home;
            } else {
                LOG.warn("Still could not find fallback proxy!");
                return;
            }
        }
        final File par = LanternClientConstants.CONFIG_DIR;
        final File to = new File(par, from.getName());
        if (!par.isDirectory() && !par.mkdirs()) {
            throw new IOException("Could not make config dir?");
        }
        LOG.debug("Copying from {} to {}", from, to);
        Files.copy(from, to);
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

    private static class ScheduledNatTraversal {
        private long scheduledTime;
        private long delay;

        public ScheduledNatTraversal(long delay) {
            super();
            this.scheduledTime = System.currentTimeMillis() + delay;
            this.delay = delay;
        }

    }
}
