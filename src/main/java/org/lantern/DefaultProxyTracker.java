package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Date;
import java.util.HashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.SystemUtils;
import org.codehaus.jackson.map.ObjectMapper;
import org.jboss.netty.handler.traffic.GlobalTrafficShapingHandler;
import org.jboss.netty.util.Timer;
import org.lantern.event.Events;
import org.lantern.event.ModeChangedEvent;
import org.lantern.event.ProxyConnectionEvent;
import org.lantern.event.ResetEvent;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.state.Peer;
import org.lantern.state.Peer.Type;
import org.lantern.util.Netty3LanternTrafficCounterHandler;
import org.lantern.util.Netty4LanternTrafficCounterHandler;
import org.lantern.util.Threads;
import org.littleshoot.util.FiveTuple;
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

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final ExecutorService p2pSocketThreadPool =
        Threads.newCachedThreadPool("P2P-Socket-Creation-Thread-");

    /**
     * These are the proxies this Lantern instance is using that can be directly
     * connected to.
     */
    ProxyQueue proxyQueue;

    /** This is are presently not used */
    private final ProxyQueue laeProxyQueue;

    /** Peer proxies that we can't directly connect to */
    private final PeerProxyQueue peerProxyQueue;

    private final Model model;

    private final PeerFactory peerFactory;

    private final Timer timer;

    private final Collection<Netty3LanternTrafficCounterHandler> netty3TrafficShapers =
            new ArrayList<Netty3LanternTrafficCounterHandler>();

    private final Collection<Netty4LanternTrafficCounterHandler> netty4TrafficShapers =
            new ArrayList<Netty4LanternTrafficCounterHandler>();


    private static final ScheduledExecutorService netty4TrafficCounterExecutor =
            Threads.newScheduledThreadPool("Netty4-Traffic-Counter-");

    /**
     * Thread pool for checking connections to proxies -- otherwise these
     * can hold up the XMPP processing thread or any other calling thread.
     */
    private final ExecutorService proxyCheckThreadPool =
            Threads.newCachedThreadPool("Proxy-Connection-Check-Pool-");

    private final XmppHandler xmppHandler;

    private final AtomicBoolean proxiesPopulated = new AtomicBoolean(false);

    private String fallbackServerHost;

    private int fallbackServerPort;

    @Inject
    public DefaultProxyTracker(final Model model,
        final PeerFactory peerFactory, final org.jboss.netty.util.Timer timer,
        final XmppHandler xmppHandler) {
        proxyQueue = new ProxyQueue(model);
        laeProxyQueue = new ProxyQueue(model);
        peerProxyQueue = new PeerProxyQueue(model);
        this.model = model;
        this.peerFactory = peerFactory;
        this.timer = timer;
        this.xmppHandler = xmppHandler;

        Events.register(this);
    }

    @Override
    public void start() {
        if (this.model.getSettings().getMode() == Mode.get) {
            prepopulateProxies();
        } else {
            log.debug("Not adding proxies in give mode...");
        }
    }


    private void prepopulateProxies() {
        if (this.model.getSettings().getMode() == Mode.give) {
            log.debug("Not loading proxies in give mode");
            return;
        }
        if (this.proxiesPopulated.get()) {
            log.debug("Proxies already populated!");
            return;
        }
        this.proxiesPopulated.set(true);
        addFallbackProxies();
        // Add all the stored proxies.
        final Collection<Peer> peers = this.model.getPeers();
        log.debug("Proxy set is: {}", peers);
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

        final File file = new File(SystemUtils.USER_HOME, ".fallbacks.json");
        if (!file.isFile()) {
            log.info("No fallback proxies in: {}", file.getAbsolutePath());
            return;
        }
        final ObjectMapper om = new ObjectMapper();
        InputStream is = null;
            
        try {
            is = new FileInputStream(file);
            final String proxy = IOUtils.toString(is);
            final FallbackProxies all = om.readValue(proxy, FallbackProxies.class);
            final Collection<FallbackProxy> proxies = all.getProxies();
            for (final FallbackProxy fp : proxies) {
                log.debug("Adding fallback: {}", fp);
                addSingleFallbackProxy(fp.getIp(), fp.getPort());
            }
        } catch (final IOException e) {
            log.error("Could not load fallback proxies?");
        }
    }

    private void addSingleFallbackProxy(final String host, final int port) {
        if (this.model.getSettings().isTcp()) {
            final URI uri = 
                LanternUtils.newURI("fallback-"+host+"@getlantern.org");
            final Peer cloud = this.peerFactory.addPeer(uri, Type.cloud);
            cloud.setMode(org.lantern.state.Mode.give);
            
            log.debug("Adding fallback: {}", host);
            addProxy(uri, host, port, Type.cloud);
        }
    }

    @Override
    public boolean isEmpty() {
        return proxyQueue.isEmpty();
    }

    @Override
    public void clear() {
        proxyQueue.clear();
        peerProxyQueue.clear();
        laeProxyQueue.clear();

        // We need to add the fallback proxy back in.
        addFallbackProxies();
    }

    @Override
    public void clearPeerProxySet() {
        peerProxyQueue.clear();
    }

    /** TODO: this is unused */
    @Override
    public void addLaeProxy(final String cur) {
        log.debug("Adding LAE proxy");
        /*
        addProxyWithChecks(this.laeProxySet, this.laeProxies,
            new ProxyHolder(cur, new InetSocketAddress(cur, 443),
                netty3TrafficCounter()), cur, Type.laeproxy);
                */
    }

    @Override
    public void addProxy(final URI fullJid, final String hostPort) {
        log.debug("Adding proxy as string: {}", hostPort);
        final String hostname =
            StringUtils.substringBefore(hostPort, ":");
        final int port =
            Integer.parseInt(StringUtils.substringAfter(hostPort, ":"));

        addProxy(fullJid, hostname, port, Type.pc);
    }


    @Override
    public void addProxy(final URI fullJid, final InetSocketAddress isa) {
        log.debug("Adding proxy: {}", isa);
        addProxy(fullJid, isa.getHostName(), isa.getPort(), Type.pc);
    }

    private void addProxy(final URI fullJid, final String host, 
            final int port, final Type type) {
        final InetSocketAddress isa = LanternUtils.isa(host, port);
        if (this.model.getSettings().getMode() == Mode.give) {
            log.debug("Not adding proxy in give mode");
            return;
        }

        addProxyWithChecks(fullJid, proxyQueue,
            new ProxyHolder(host, fullJid, isa, netty3TrafficCounter(), type));
    }


    @Override
    public boolean hasJidProxy(final URI uri) {
        return peerProxyQueue.containsPeer(uri);
    }

    @Override
    public void addJidProxy(final URI peerUri) {
        log.debug("Considering peer proxy");
        if (this.model.getSettings().getMode() == Mode.give) {
            log.debug("Not adding JID proxy in give mode");
            return;
        }
        final String jid = peerUri.toASCIIString();
        final HashMap<URI, AtomicInteger> peerFailureCount =
                new HashMap<URI, AtomicInteger>();

        p2pSocketThreadPool.submit(new Runnable() {
            @Override
            public void run() {
                // TODO: In the past we created a bunch of connections here -
                // a socket pool -- to avoid dealing with connection time
                // delays. We should probably do that again!.
                try {
                    log.debug("Opening outgoing peer...");
                    final FiveTuple tuple = LanternUtils.openOutgoingPeer(
                        peerUri, xmppHandler.getP2PClient(),
                        peerFailureCount);
                    log.debug("Got tuple and adding it for peer: {}", peerUri);

                    final InetSocketAddress remote = tuple.getRemote();
                    final ProxyHolder ph =
                        new ProxyHolder(jid, peerUri, tuple, netty4TrafficCounter(),
                                Type.pc);

                    peerFactory.onOutgoingConnection(peerUri, remote, Type.pc,
                            ph.getTrafficShapingHandler());

                    peerProxyQueue.addPeerProxy(peerUri, ph);

                    Events.eventBus().post(
                            new ProxyConnectionEvent(
                                    ConnectivityStatus.CONNECTED));

                } catch (final IOException e) {
                    log.info("Could not create peer socket", e);
                }
            }
        });
    }

    private void restoreRecentlyDeceasedProxies(ProxyQueue queue) {
        synchronized (queue) {
            while (true) {
                final ProxyHolder proxy = queue.pausedProxies.poll();
                if (proxy == null) {
                    log.debug("No proxy!");
                    break;
                }
                log.debug("Attempting to restore" + proxy);
                addProxyWithChecks(proxy.getJid(), queue, proxy);
            }
        }
    }

    private void restoreTimedInProxies(ProxyQueue queue) {
        synchronized(queue) {
            long now = new Date().getTime();
            while (true) {
                ProxyHolder proxy = queue.pausedProxies.peek();
                if (proxy == null) 
                    break;
                if (now > proxy.getRetryTime()) {
                    log.debug("Attempting to restore timed-in proxy " + proxy);
                    addProxyWithChecks(proxy.getJid(), queue, proxy);
                    queue.pausedProxies.remove();
                } else {
                    break;
                }
            }
        }
    }
    @Override
    public void addProxyWithChecks(final URI fullJid,
        final ProxyQueue queue, final ProxyHolder ph) {
        if (!this.model.getSettings().isTcp()) {
            //even with no tcp, we can still add JID proxies
            addJidProxy(fullJid);
            log.debug("Not checking proxy when not running with TCP");
            return;
        }
        if (queue.contains(ph)) {
            log.debug("We already know about proxy "+ph+" in {}", queue);
            //but it might be disconnected
            if (!ph.lastFailed()) {
                log.debug("Proxy considered connected");
                return;
            }
        }

        log.debug("Trying to add proxy {} to queue {}", ph, queue);

        proxyCheckThreadPool.submit(new Runnable() {

            @Override
            public void run() {
                final Socket sock = new Socket();
                final InetSocketAddress remote = ph.getFiveTuple().getRemote();
                try {
                    sock.connect(remote, 60*1000);

                    if (queue.add(ph)) {
                        log.debug("Added connected TCP proxy. "
                                + "Queue is now: {}", queue);
                        peerFactory.onOutgoingConnection(fullJid, remote,
                                ph.getType(), ph.getTrafficShapingHandler());
                    }

                    ph.addSuccess();
                    log.debug("Dispatching CONNECTED event");
                    Events.asyncEventBus().post(
                        new ProxyConnectionEvent(ConnectivityStatus.CONNECTED));
                } catch (final IOException e) {
                    // This can happen if the user has subsequently gone 
                    // offline, for example.
                    log.debug("Could not connect to: " + ph, e);
                    onCouldNotConnect(ph);
                    
                    // Try adding the proxy by it's JID! This can happen, for 
                    // example, if we get a bogus port mapping.
                    addJidProxy(fullJid);
                } finally {
                    IOUtils.closeQuietly(sock);
                }
            }
        });
    }

    @Override
    public void onCouldNotConnect(final ProxyHolder ph) {
        // This can happen in several scenarios. First, it can happen if you've
        // actually disconnected from the internet. Second, it can happen if
        // the proxy is blocked. Third, it can happen when the proxy is simply
        // down for some reason.

        // We should remove the proxy here but should certainly keep it on disk
        // so we can try to connect to it in the future.
        log.info("COULD NOT CONNECT TO STANDARD PROXY!! Proxy address: {}",
            ph.getFiveTuple());

        onCouldNotConnect(ph, proxyQueue);
    }

    @Override
    public void onCouldNotConnectToLae(final ProxyHolder ph) {
        log.info("COULD NOT CONNECT TO LAE PROXY!! Proxy address: {}",
            ph.getFiveTuple());

        // For now we assume this is because we've lost our connection.
        onCouldNotConnect(ph, laeProxyQueue);
    }

    private void onCouldNotConnect(final ProxyHolder proxyAddress,
        final ProxyQueue queue){
        log.info("COULD NOT CONNECT!! Proxy address: {}", proxyAddress);
        queue.proxyFailed(proxyAddress);
    }

    @Override
    public void onCouldNotConnectToPeer(final URI peerUri) {
        peerProxyQueue.proxyFailed(peerUri);
    }

    @Override
    public void onError(final URI peerUri) {
        peerProxyQueue.proxyFailed(peerUri);
    }

    @Override
    public void removePeer(final URI uri) {
        log.debug("Removing peer by request: {}", uri);
        peerProxyQueue.removeProxy(uri);
    }

    @Override
    public ProxyHolder getLaeProxy() {
        restoreTimedInProxies(laeProxyQueue);
        return laeProxyQueue.getProxy();
    }

    @Override
    public ProxyHolder getProxy() {
        restoreTimedInProxies(proxyQueue);
        return proxyQueue.getProxy();
    }

    @Subscribe
    public void onConnectivityChanged(ConnectivityChangedEvent e) {
        log.debug("Got connectivity changed event: {}", e);
        if (e.isConnected()) {
            log.debug("Restoring proxies: {}", proxyQueue);
            restoreRecentlyDeceasedProxies(proxyQueue);
            restoreRecentlyDeceasedProxies(laeProxyQueue);
            restoreRecentlyDeceasedProxies(peerProxyQueue);
        } 
    }

    @Override
    public ProxyHolder getJidProxy() {
        restoreTimedInProxies(peerProxyQueue);
        return peerProxyQueue.getProxy();
    }

    @Override
    public boolean hasProxy() {
        return !proxyQueue.isEmpty();
    }

    @Subscribe
    public void onReset(final ResetEvent event) {
        clear();
    }

    @Override
    public void stop() {
        for (final GlobalTrafficShapingHandler handler : this.netty3TrafficShapers) {
            handler.releaseExternalResources();
        }
    }

    @Subscribe
    public void onModeChanged(final ModeChangedEvent event) {
        log.debug("Received mode changed event: {}", event);
        start();
    }

    private Netty3LanternTrafficCounterHandler netty3TrafficCounter() {
        final Netty3LanternTrafficCounterHandler handler =
            new Netty3LanternTrafficCounterHandler(this.timer);
        netty3TrafficShapers.add(handler);
        return handler;
    }

    private Netty4LanternTrafficCounterHandler netty4TrafficCounter() {
        final Netty4LanternTrafficCounterHandler handler =
                new Netty4LanternTrafficCounterHandler(
                        netty4TrafficCounterExecutor);
        netty4TrafficShapers.add(handler);
        return handler;
    }

    @Override
    public void setSuccess(ProxyHolder proxyHolder) {
        proxyHolder.resetFailures();
    }

    class PeerProxyQueue extends ProxyQueue {
        //this unfortunately duplicates the values of proxyMap
        //but there doesn't seem to be an elegant way to handle
        //this
        private final HashMap<URI, ProxyHolder> peerProxyMap =
                new HashMap<URI, ProxyHolder>();

        PeerProxyQueue(Model model) {
            super(model);
        }

        public void proxyFailed(URI peerUri) {
            ProxyHolder proxy = peerProxyMap.get(peerUri);
            if (proxy != null) {
                proxyFailed(proxy);
            }
        }

        public synchronized void removeProxy(URI uri) {
            if (peerProxyMap.containsKey(uri)) {
                ProxyHolder proxy = peerProxyMap.remove(uri);
                proxySet.remove(proxy);
                proxies.remove(proxy);
                pausedProxies.remove(proxy);
            }
        }

        public synchronized void addPeerProxy(URI peerUri, ProxyHolder ph) {
            if (!peerProxyMap.containsKey(peerUri)) {
                peerProxyMap.put(peerUri, ph);
                add(ph);
                log.debug("Queue is now: {}", peerProxyQueue);
            } else {
                proxies.add(ph);
            }
        }

        public boolean containsPeer(URI uri) {
            return peerProxyMap.containsKey(uri);
        }

        @Override
        protected synchronized void reenqueueProxy(ProxyHolder proxy) {
            // We handle p2p JIDs a little differently, as we can't make multiple
            // connections from ephemeral local ports to the same remote endpoint
            // because NAT traversal is local port-specific (at least in many
            // cases). So instead of always adding the proxy back to the end of
            // the queue, we add it using the full FiveTuple creation process
            // from the beginning.
            addJidProxy(LanternUtils.newURI(proxy.getId()));
            log.debug("FIFO queue is now: {}", proxies);
        }
    }


    private void parseFallbackProxy() {
        final File file = 
            new File(LanternClientConstants.CONFIG_DIR, "fallback.json");
        if (!file.isFile()) {
            try {
                copyFallback();
            } catch (final IOException e) {
                log.error("Could not copy fallback?", e);
            }
        }
        if (!file.isFile()) {
            log.error("No fallback proxy to load!");
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
            log.debug("Set fallback proxy to {}", fallbackServerHost);
        } catch (final IOException e) {
            log.error("Could not load fallback", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
    }

    private void copyFallback() throws IOException {
        log.debug("Copying fallback file");
        final File from;
        
        final File home = 
            new File(new File(SystemUtils.USER_HOME), "fallback.json");
        if (home.isFile()) {
            from = home;
        } else {
            log.debug("No fallback proxy found in home - checking cur...");
            final File curDir = new File("fallback.json");
            if (curDir.isFile()) {
                from = curDir;
            } else {
                log.warn("Still could not find fallback proxy!");
                return;
            }
        }
        final File par = LanternClientConstants.CONFIG_DIR;
        final File to = new File(par, from.getName());
        if (!par.isDirectory() && !par.mkdirs()) {
            throw new IOException("Could not make config dir?");
        }
        Files.copy(from, to);
    }


}
