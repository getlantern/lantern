package org.lantern;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Queue;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.jboss.netty.handler.traffic.GlobalTrafficShapingHandler;
import org.jboss.netty.util.Timer;
import org.lantern.event.Events;
import org.lantern.event.ProxyConnectionEvent;
import org.lantern.event.ResetEvent;
import org.lantern.event.SetupCompleteEvent;
import org.lantern.state.Model;
import org.lantern.state.Peer.Type;
import org.lantern.state.Settings.Mode;
import org.lantern.util.Netty3LanternTrafficCounterHandler;
import org.lantern.util.Netty4LanternTrafficCounterHandler;
import org.lantern.util.Threads;
import org.littleshoot.util.FiveTuple;
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

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final ExecutorService p2pSocketThreadPool = 
        Threads.newCachedThreadPool("P2P-Socket-Creation-Thread-");
    
    /**
     * These are the centralized proxies this Lantern instance is using.
     */
    private final Set<ProxyHolder> proxySet =
        new HashSet<ProxyHolder>();
    private final Queue<ProxyHolder> proxies =
        new ConcurrentLinkedQueue<ProxyHolder>();

    /**
     * This is the set of the peer proxies we know about only through their
     * JIDs - i.e. they don't have their ports mapped such that we can 
     * access them directly.
     */
    private final Map<URI, ProxyHolder> peerProxyMap = 
            new ConcurrentHashMap<URI, ProxyHolder>();
    private final Queue<ProxyHolder> peerProxyQueue =
            new ConcurrentLinkedQueue<ProxyHolder>();

    private final Set<ProxyHolder> laeProxySet =
        new HashSet<ProxyHolder>();
    private final Queue<ProxyHolder> laeProxies =
        new ConcurrentLinkedQueue<ProxyHolder>();

    //private final PeerProxyManager peerProxyManager;

    private final Model model;

    private final PeerFactory peerFactory;

    private final Timer timer;
    
    private boolean populatedProxies = false;
    
    private Collection<Netty3LanternTrafficCounterHandler> netty3TrafficShapers =
            new ArrayList<Netty3LanternTrafficCounterHandler>();
    
    private Collection<Netty4LanternTrafficCounterHandler> netty4TrafficShapers =
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

    @Inject
    public DefaultProxyTracker(final Model model,
        final PeerFactory peerFactory, final org.jboss.netty.util.Timer timer,
        final XmppHandler xmppHandler) {
        this.model = model;
        this.peerFactory = peerFactory;
        this.timer = timer;
        this.xmppHandler = xmppHandler;
        
        Events.register(this);
    }
    
    @Override
    public void start() {
        if (this.model.isSetupComplete()) {
            addFallbackProxy();
            prepopulateProxies();
            populatedProxies = true;
        } else {
            log.debug("Not starting when setup is not complete...");
        }
    }
    

    private void prepopulateProxies() {
        if (this.model.getSettings().getMode() == Mode.give) {
            log.debug("Not loading proxies in give mode");
            return;
        }
        // Add all the stored proxies.
        final Collection<String> saved = this.model.getSettings().getProxies();
        log.debug("Proxy set is: {}", saved);
        for (final String proxy : saved) {
            // Don't use peer proxies since we're not connected to XMPP yet.
            if (proxy.contains("appspot")) {
                addLaeProxy(proxy);
            } else if (!proxy.contains("@")) {
                addProxy(proxy);
            }
        }
    }

    private void addFallbackProxy() {
        if (this.model.getSettings().isTcp()) {
            addProxy(LanternClientConstants.FALLBACK_SERVER_HOST, 
                Integer.parseInt(LanternClientConstants.FALLBACK_SERVER_PORT), 
                Type.cloud);
        }
    }

    @Override
    public boolean isEmpty() {
        return this.proxies.isEmpty();
    }

    @Override
    public void clear() {
        this.proxies.clear();
        this.proxySet.clear();
        this.peerProxyMap.clear();
        this.laeProxySet.clear();
        this.laeProxies.clear();

        // We need to add the fallback proxy back in.
        addFallbackProxy();
    }

    @Override
    public void clearPeerProxySet() {
        this.peerProxyMap.clear();
    }


    private void proxyBookkeeping(final String proxy) {
        log.debug("Adding proxy to settings");
        
        // We want to keep track of it for future user regardless of whether
        // or not we can connect now.
        
        // This is a little odd because the proxy could have 
        // originally come from the settings themselves, but 
        // it'll remove duplicates, so no harm done.
        model.getSettings().addProxy(proxy);
    }

    @Override
    public void addLaeProxy(final String cur) {
        log.debug("Adding LAE proxy");
        addProxyWithChecks(this.laeProxySet, this.laeProxies,
            new ProxyHolder(cur, new InetSocketAddress(cur, 443), 
                netty3TrafficCounter()), cur, Type.laeproxy);
    }

    @Override
    public void addProxy(final String hostPort) {
        log.debug("Adding proxy as string: {}", hostPort);
        final String hostname = 
            StringUtils.substringBefore(hostPort, ":");
        final int port = 
            Integer.parseInt(StringUtils.substringAfter(hostPort, ":"));
        
        addProxy(hostname, port, Type.desktop);
    }


    @Override
    public void addProxy(final InetSocketAddress isa) {
        log.debug("Adding proxy: {}", isa);
        addProxy(isa.getHostName(), isa.getPort(), Type.desktop);
    }
    
    private void addProxy(final String host, final int port, final Type type) {
        final InetSocketAddress isa = LanternUtils.isa(host, port);
        if (this.model.getSettings().getMode() == Mode.give) {
            log.debug("Not adding proxy in give mode");
            return;
        }
        
        addProxyWithChecks(proxySet, proxies, 
            new ProxyHolder(host, isa, netty3TrafficCounter()),
                host+":"+port, type);
    }
    
    private ProxyHolder getProxy(final Queue<ProxyHolder> queue) {
        synchronized (queue) {
            if (queue.isEmpty()) {
                log.debug("No proxy addresses");
                return null;
            }
            final ProxyHolder proxy = queue.remove();
            queue.add(proxy);
            log.debug("FIFO queue is now: {}", queue);
            return proxy;
        }
    }


    @Override
    public boolean hasJidProxy(final URI uri) {
        return this.peerProxyMap.containsKey(uri);
    }
    
    @Override
    public void addJidProxy(final URI peerUri) {
        log.debug("Considering peer proxy");
        if (this.model.getSettings().getMode() == Mode.give) {
            log.debug("Not adding JID proxy in give mode");
            return;
        }
        final String jid = peerUri.toASCIIString();
        proxyBookkeeping(jid);
        
        // The idea here is to start with the JID and to basically convert it
        // into a NAT/firewall traversed FiveTuple containing a local and 
        // remote InetSocketAddress we can use a little more easily.
        final Map<URI, AtomicInteger> peerFailureCount =
                new HashMap<URI, AtomicInteger>();

        p2pSocketThreadPool.submit(new Runnable() {
            @Override
            public void run() {
                // TODO: In the past we created a bunch of connections here -
                // a socket pool -- to avoid dealing with connection time 
                // delays. We should probably do that again!.
                boolean gotConnected = false;
                try {
                    log.debug("Opening outgoing peer...");
                    final FiveTuple tuple = LanternUtils.openOutgoingPeer(
                        peerUri, xmppHandler.getP2PClient(),
                        peerFailureCount);
                    log.debug("Got tuple and adding it for peer: {}", peerUri);

                    final InetSocketAddress remote = tuple.getRemote();
                    final ProxyHolder ph =
                        new ProxyHolder(jid, tuple, netty4TrafficCounter());
                    
                    peerFactory.addOutgoingPeer(jid, remote, Type.desktop, 
                            ph.getTrafficShapingHandler());
                    
                    synchronized (peerProxyMap) {
                        if (!peerProxyMap.containsKey(peerUri)) {
                            peerProxyMap.put(peerUri, ph);
                            peerProxyQueue.add(ph);
                            log.debug("Queue is now: {}", peerProxyQueue);
                        }
                    }
                    if (!gotConnected) {
                        Events.eventBus().post(
                            new ProxyConnectionEvent(
                                ConnectivityStatus.CONNECTED));
                    }
                    gotConnected = true;
                } catch (final IOException e) {
                    log.info("Could not create peer socket", e);
                }
            }
        });
    }
    
    private void addProxyWithChecks(final Set<ProxyHolder> set,
        final Queue<ProxyHolder> queue, final ProxyHolder ph,
        final String fullProxyString, final Type type) {
        if (!this.model.getSettings().isTcp()) {
            log.debug("Not checking proxy when not running with TCP");
            return;
        }
        if (set.contains(ph)) {
            log.debug("We already know about proxy "+ph+" in {}", set);
            return;
        }
        proxyBookkeeping(fullProxyString);
        
        proxyCheckThreadPool.submit(new Runnable() {
            
            @Override
            public void run() {
                final Socket sock = new Socket();
                final InetSocketAddress remote = ph.getFiveTuple().getRemote();
                try {
                    sock.connect(remote, 60*1000);
                    
                    synchronized (set) {
                        if (!set.contains(ph)) {
                            set.add(ph);
                            queue.add(ph);
                            log.debug("Added connected TCP proxy. " +
                                "Queue is now: {}", queue);
                            peerFactory.addOutgoingPeer("", remote, type, 
                                    ph.getTrafficShapingHandler());
                        }
                    }
                    
                    log.debug("Dispatching CONNECTED event");
                    Events.asyncEventBus().post(
                        new ProxyConnectionEvent(ConnectivityStatus.CONNECTED));
                } catch (final IOException e) {
                    log.error("Could not connect to: " + ph, e);
                    onCouldNotConnect(ph);
                    model.getSettings().removeProxy(fullProxyString);
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

        onCouldNotConnect(ph, this.proxySet, this.proxies);
    }

    @Override
    public void onCouldNotConnectToLae(final ProxyHolder ph) {
        log.info("COULD NOT CONNECT TO LAE PROXY!! Proxy address: {}",
            ph.getFiveTuple());

        // For now we assume this is because we've lost our connection.
        onCouldNotConnect(ph, this.laeProxySet, this.laeProxies);
    }

    private void onCouldNotConnect(final ProxyHolder proxyAddress,
        final Set<ProxyHolder> set, final Queue<ProxyHolder> queue){
        log.info("COULD NOT CONNECT!! Proxy address: {}", proxyAddress);
        synchronized (this.proxySet) {
            set.remove(proxyAddress);
            queue.remove(proxyAddress);
        }
    }

    @Override
    public void onCouldNotConnectToPeer(final URI peerUri) {
        removePeer(peerUri);
    }

    @Override
    public void onError(final URI peerUri) {
        removePeer(peerUri);
    }

    @Override
    public void removePeer(final URI uri) {
        log.debug("Removing peer on error or connection failure: {}", uri);
        synchronized (this.peerProxyMap) {
            final ProxyHolder ph = this.peerProxyMap.remove(uri);
            if (ph == null) {
                // This will typically be the case for give mode peers who
                // just may not store the peer in the first place.
                log.debug("Peer not in map?", uri);
            } else {
                this.peerProxyQueue.remove(ph);
            }
        }
    }

    @Override
    public ProxyHolder getLaeProxy() {
        return getProxy(this.laeProxies);
    }

    @Override
    public ProxyHolder getProxy() {
        return getProxy(this.proxies);
    }
    
    @Override
    public ProxyHolder getJidProxy() {
        // We handle p2p JIDs a little differently, as we can't make multiple
        // connections from ephemeral local ports to the same remote endpoint
        // because NAT traversal is local port-specific (at least in many
        // cases). So instead of always adding the proxy back to the end of 
        // the queue, we add it using the full FiveTuple creation process
        // from the beginning.
        synchronized (this.peerProxyQueue) {
            if (this.peerProxyQueue.isEmpty()) {
                log.debug("No proxy addresses");
                return null;
            }
            final ProxyHolder proxy = this.peerProxyQueue.remove();
            addJidProxy(LanternUtils.newURI(proxy.getId()));
            log.debug("FIFO queue is now: {}", this.peerProxyQueue);
            return proxy;
        }
    }
    
    @Override
    public boolean hasProxy() {
        return !this.proxies.isEmpty();
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
    public void onSetupComplete(final SetupCompleteEvent event) {
        log.debug("Got setup complete!");
        if (this.populatedProxies) {
            log.info("Already populated proxies?");
            return;
        }
        start();
    }
    
    private Netty3LanternTrafficCounterHandler netty3TrafficCounter() {
        final Netty3LanternTrafficCounterHandler handler = 
            new Netty3LanternTrafficCounterHandler(this.timer, false);
        netty3TrafficShapers.add(handler);
        return handler;
    }
    
    private Netty4LanternTrafficCounterHandler netty4TrafficCounter() {
        final Netty4LanternTrafficCounterHandler handler =
                new Netty4LanternTrafficCounterHandler(
                        netty4TrafficCounterExecutor, false);
        netty4TrafficShapers.add(handler);
        return handler;
    }

}
