package org.lantern;

import static org.lantern.state.Peer.Type.*;
import static org.littleshoot.util.FiveTuple.Protocol.*;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
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
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;
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
    private static final FiveTuple EMPTY_UDP_TUPLE = new FiveTuple(null, null,
            UDP);

    private static final Logger LOG = LoggerFactory
            .getLogger(DefaultProxyTracker.class);

    private final ProxyPrioritizer PROXY_PRIORITIZER = new ProxyPrioritizer();

    private final String CONFIG_FILENAME = "fallback.json";

    private final File[] FALLBACK_CONFIG_INSTALL_PATHS = {
            new File(new File(SystemUtils.USER_HOME), CONFIG_FILENAME),
            new File(new File(SystemUtils.USER_DIR), CONFIG_FILENAME)};

    private final ExecutorService p2pSocketThreadPool =
            Threads.newCachedThreadPool("P2P-Socket-Creation-Thread-");

    /**
     * Holds all proxies.
     */
    private final Set<ProxyHolder> proxies = Collections
            .synchronizedSet(new HashSet<ProxyHolder>());

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

    private final ScheduledExecutorService proxyRetryService = Threads
            .newSingleThreadScheduledExecutor("Proxy-Retry");

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

    private FallbackProxyConfig fallbackProxyConfig;

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

        addProxy(jid, address, Type.pc);
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
        proxy.addFailure();
        notifyProxiesSize();
    }

    @Override
    public void onError(final URI peerUri) {
        for (ProxyHolder proxy : proxies) {
            if (proxy.getJid().equals(peerUri)) {
                proxy.addFailure();
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

    @Subscribe
    public void onModeChanged(final ModeChangedEvent event) {
        LOG.debug("Received mode changed event: {}", event);
        start();
    }

    @Override
    public Collection<ProxyHolder> getConnectedProxiesInOrderOfFallbackPreference() {
        List<ProxyHolder> result = new ArrayList<ProxyHolder>();
        for (ProxyHolder proxy : proxies) {
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
    public ProxyHolder firstConnectedTcpProxyBlocking()
            throws InterruptedException {
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

    private void addProxy(URI jid, InetSocketAddress address, Type type) {
        boolean canAddAsTCP = address != null && address.getPort() > 0
                && this.model.getSettings().isTcp();
        FiveTuple fiveTuple = canAddAsTCP ? new FiveTuple(null, address, TCP) :
                EMPTY_UDP_TUPLE;
        ProxyHolder proxy = new ProxyHolder(this, peerFactory,
                lanternTrustStore, jid, fiveTuple, type);
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
            checkConnectivityToProxy(proxy);
        }
    }

    private void checkConnectivityToProxy(ProxyHolder proxy) {
        if (proxy.isNatTraversed()) {
            checkConnectivityToNattedProxy(proxy);
        } else {
            checkConnectivityToTcpProxy(proxy);
        }
    }

    private void checkConnectivityToTcpProxy(final ProxyHolder proxy) {
        proxyCheckThreadPool.submit(new Runnable() {
            @Override
            public void run() {
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
        });
    }

    private void checkConnectivityToNattedProxy(final ProxyHolder proxy) {
        p2pSocketThreadPool.submit(new Runnable() {
            @Override
            public void run() {
                // TODO: In the past we created a bunch of connections here -
                // a socket pool -- to avoid dealing with connection time
                // delays. We should probably do that again!.
                try {
                    LOG.debug("Opening outgoing peer...");
                    // Not sure what this is for
                    Map<URI, AtomicInteger> peerFailureCount =
                            new HashMap<URI, AtomicInteger>();
                    final FiveTuple newFiveTuple = LanternUtils.openOutgoingPeer(
                            proxy.getJid(), xmppHandler.getP2PClient(),
                            peerFailureCount);
                    
                    ProxyHolder newProxy = new ProxyHolder(DefaultProxyTracker.this,
                            peerFactory,
                            lanternTrustStore,
                            proxy.getJid(),
                            newFiveTuple,
                            proxy.getType());
                    LOG.debug("Got tuple and adding it for proxy: {}", newProxy);
                    proxies.add(newProxy);
                    successfullyConnectedToProxy(newProxy);
                    proxies.remove(proxy);
                    LOG.debug("Proxies is now {}", proxies);
                } catch (final IOException e) {
                    LOG.info("Could not create peer socket", e);
                    proxy.addFailure();
                }
            }
        });
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
                new ProxyConnectionEvent(
                        ConnectivityStatus.CONNECTED));

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
    }

    private void restoreTimedInProxies() {
        long now = new Date().getTime();
        for (ProxyHolder proxy : proxies) {
            if (proxy.needsConnectionTest() && now > proxy.getRetryTime()) {
                LOG.debug("Attempting to restore timed-in proxy: {}", proxy);
                checkConnectivityToProxy(proxy);
            } else {
                LOG.debug("Ignoring timed-in proxy: {}", proxy);
                break;
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
                proxy.resetFailures();
                checkConnectivityToProxy(proxy);
            } else {
                LOG.debug("Proxy does not need a connection test: {}", proxy);
                break;
            }
        }
    }

    private void prepopulateProxies() {
        LOG.debug("Attempting to pre-populate proxies");
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

        // For now, we don't pre-populate stored proxies that are not standard
        // fallbacks because we don't have a way to exchange updated 
        // certificates with them yet (we do that
        // over XMPP, but at this point we don't even have a fallback so may
        // not be able to connected to XMPP...chicken/egg).
    }

    private void addFallbackProxies() {
        LOG.debug("Attempting to add fallback proxies");
        for (FallbackProxy fp : getFallbackProxyConfig().getProxies()) {
            LOG.debug("Adding fallback: {}", fp);
            if (this.model.getSettings().isTcp()) {
                String host = fp.getIp();
                final URI uri =
                    LanternUtils.newURI("fallback-" + host
                                        + "@getlantern.org");
                final Peer cloud = this.peerFactory.addPeer(uri, Type.cloud);
                cloud.setMode(org.lantern.state.Mode.give);
                LOG.debug("Adding fallback: {}", host);
                addProxy(uri, LanternUtils.isa(host,
                                               fp.getPort()),
                                               Type.cloud);
            }
        }
    }

    @Override
    public String getFallbackProxyConfigCookie() {
        return getFallbackProxyConfig().getCookie();
    }

    private FallbackProxyConfig getFallbackProxyConfig() {
        if (fallbackProxyConfig == null) {
            File file = getConfigFile();
            if (!file.isFile()) {
                try {
                    copyFallback();
                } catch (final IOException e) {
                    LOG.warn("Could not copy fallback?", e);
                    return null;
                }
                file = getConfigFile();
                if (!file.isFile()) {
                    LOG.error("No fallback proxy config to load!");
                    return null;
                }
            }
            final ObjectMapper om = new ObjectMapper();
            InputStream is = null;
            try {
                is = new FileInputStream(file);
                fallbackProxyConfig = om.readValue(
                        IOUtils.toString(is), FallbackProxyConfig.class);
            } catch (final IOException e) {
                LOG.error("Could not load fallback", e);
                return null;
            } finally {
                IOUtils.closeQuietly(is);
            }
        }
        return fallbackProxyConfig;
    }

    @Override
    public void setFallbackProxyConfig(String text) {
        saveFallbackProxyConfig(getConfigFile(), text, true);
        // We try and save it to all directories from which we may try and
        // load it later.  This will only matters if and when we run
        // Lantern as a different user than the one that got the latest
        // setFallbackProxyConfig update.  So it's not a showstopper if it
        // fails but it's still worth trying.
        for (File out : FALLBACK_CONFIG_INSTALL_PATHS) {
            saveFallbackProxyConfig(out, text, false);
        }
    }

    private void saveFallbackProxyConfig(File file,
                                         String text,
                                         boolean crucial) {
        try {
            if (file == null) {
                throw new IOException();
            }
            BufferedWriter out = new BufferedWriter(new FileWriter(file));
            try {
                out.write(text);
            } finally {
                out.close();
            }
            reloadFallbackProxies();
        } catch (IOException e) {
            String errMsg = "Couldn't write new fallback config to " + file;
            if (crucial) {
                LOG.error(errMsg);
            } else {
                LOG.debug(errMsg);
            }
        }
    }

    private void reloadFallbackProxies() {
        fallbackProxyConfig = null;
        LOG.debug("Adding controller-fed proxies; "
                + "ignore duplication warnings below.");
        addFallbackProxies();
    }

    private File getConfigFile() {
        final File par = LanternClientConstants.CONFIG_DIR;
        if (!par.isDirectory() && !par.mkdirs()) {
            return null;
        }
        return new File(par, CONFIG_FILENAME);
    }

    private void copyFallback() throws IOException {
        LOG.debug("Copying fallback file");
        for (File from : FALLBACK_CONFIG_INSTALL_PATHS) {
            if (from.isFile()) {
                copyFallbackConfig(from);
                return;
            } else {
                LOG.debug("No fallback config in " + from);
            }
        }
        LOG.warn("No fallback config found at all!");
    }

    private void copyFallbackConfig(File from) throws IOException {
        File to = getConfigFile();
        if (to == null) {
            throw new IOException("Could not make config dir?");
        } else {
            LOG.debug("Copying from {} to {}", from, to);
            Files.copy(from, to);
        }
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
}
