package org.lantern;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.Queue;
import java.util.Set;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.ExecutorService;

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
import org.lantern.util.LanternTrafficCounterHandler;
import org.lantern.util.Threads;
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

    /**
     * These are the centralized proxies this Lantern instance is using.
     */
    private final Set<ProxyHolder> proxySet =
        new HashSet<ProxyHolder>();
    private final Queue<ProxyHolder> proxies =
        new ConcurrentLinkedQueue<ProxyHolder>();

    /**
     * This is the set of all peer proxies we know about. We may have
     * established connections with some of them. The main purpose of this is
     * to avoid exchanging keys multiple times.
     */
    private final Set<String> peerProxySet = new HashSet<String>();

    private final Set<ProxyHolder> laeProxySet =
        new HashSet<ProxyHolder>();
    private final Queue<ProxyHolder> laeProxies =
        new ConcurrentLinkedQueue<ProxyHolder>();

    private final PeerProxyManager peerProxyManager;

    private final Model model;

    private final PeerFactory peerFactory;

    private final Timer timer;
    
    private boolean populatedProxies = false;
    
    
    /**
     * Thread pool for checking connections to proxies -- otherwise these
     * can hold up the XMPP processing thread or any other calling thread.
     */
    private final ExecutorService proxyCheckThreadPool = 
            Threads.newCachedThreadPool("Proxy-Connection-Check-Pool-");

    @Inject
    public DefaultProxyTracker(final Model model,
        final PeerProxyManager trustedPeerProxyManager,
        final PeerFactory peerFactory, final org.jboss.netty.util.Timer timer) {
        this.model = model;
        this.peerProxyManager = trustedPeerProxyManager;
        this.peerFactory = peerFactory;
        this.timer = timer;
        
        Events.register(this);
    }
    
    @Override
    public void start() {
        if (this.model.isSetupComplete()) {
            addFallbackProxy();
            prepopulateProxies();
            populatedProxies = true;
        }
    }
    

    private void prepopulateProxies() {
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
        addProxy(LanternClientConstants.FALLBACK_SERVER_HOST, 
            Integer.parseInt(LanternClientConstants.FALLBACK_SERVER_PORT), 
            Type.cloud);
    }

    @Override
    public boolean isEmpty() {
        return this.proxies.isEmpty();
    }

    @Override
    public void clear() {
        this.proxies.clear();
        this.proxySet.clear();
        this.peerProxySet.clear();
        this.laeProxySet.clear();
        this.laeProxies.clear();

        // We need to add the fallback proxy back in.
        addFallbackProxy();
    }

    @Override
    public void clearPeerProxySet() {
        this.peerProxySet.clear();
    }


    @Override
    public boolean addJidProxy(final String peerUri) {
        log.debug("Considering peer proxy");
        // The idea here is to start with the JID and to basically convert it
        // into a NAT/firewall traversed FiveTuple containing a locale and 
        // remote InetSocketAddress we can use a little more easily.
        
        //addPeerProxyWithChecks(this.peerProxySet, )
        synchronized (peerProxySet) {
            // TODO: I believe this excludes exchanging keys with peers who
            // are on multiple machines when the peer URI is a general JID and
            // not an instance JID.
            if (!peerProxySet.contains(peerUri)) {
                log.debug("Actually adding peer proxy: {}", peerUri);
                peerProxySet.add(peerUri);
                return true;
            } else {
                log.debug("We already know about the peer proxy");
            }
        }
        return false;
    }


    @Override
    public void addLaeProxy(final String cur) {
        log.debug("Adding LAE proxy");
        addProxyWithChecks(this.laeProxySet, this.laeProxies,
            new ProxyHolder(cur, new InetSocketAddress(cur, 443), 
                trafficTracker()), cur, Type.laeproxy);
    }
    
    private Collection<GlobalTrafficShapingHandler> trafficShapers =
            new ArrayList<GlobalTrafficShapingHandler>();
    
    private LanternTrafficCounterHandler trafficTracker() {
        final LanternTrafficCounterHandler handler = 
            new LanternTrafficCounterHandler(this.timer, false);
        trafficShapers.add(handler);
        return handler;
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
        addProxyWithChecks(proxySet, proxies, 
            new ProxyHolder(host, isa, trafficTracker()),
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

    private void addProxyWithChecks(final Set<ProxyHolder> set,
        final Queue<ProxyHolder> queue, final ProxyHolder ph,
        final String fullProxyString, final Type type) {
        if (set.contains(ph)) {
            log.debug("We already know about proxy "+ph+" in {}", set);
            return;
        }

        final Runnable run = new Runnable() {
            
            @Override
            public void run() {
                final Socket sock = new Socket();
                try {
                    sock.connect(ph.getIsa(), 60*1000);
                    // This is a little odd because the proxy could have 
                    // originally come from the settings themselves, but 
                    // it'll remove duplicates, so no harm done.
                    log.debug("Adding proxy to settings: {}", model.getSettings());
                    model.getSettings().addProxy(fullProxyString);
                    
                    peerFactory.addPeer("", ph.getIsa().getAddress(), 
                        ph.getIsa().getPort(), type, false, 
                        ph.getTrafficShapingHandler());
                    synchronized (set) {
                        if (!set.contains(ph)) {
                            set.add(ph);
                            queue.add(ph);
                            log.debug("Queue is now: {}", queue);
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
        };
        proxyCheckThreadPool.submit(run);

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
            ph.getIsa());

        onCouldNotConnect(ph, this.proxySet, this.proxies);
    }

    @Override
    public void onCouldNotConnectToLae(final ProxyHolder ph) {
        log.info("COULD NOT CONNECT TO LAE PROXY!! Proxy address: {}",
            ph.getIsa());

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
        // We always remove from both since their trusted status could have
        // changed
        removePeerUri(uri);
        removeAnonymousPeerUri(uri);
        //if (LanternHub.getTrustedContactsManager().isJidTrusted(uri.toASCIIString())) {
            peerProxyManager.removePeer(uri);
        //} else {
        //    LanternHub.anonymousPeerProxyManager().removePeer(uri);
        //}
    }

    private void removePeerUri(final URI peerUri) {
        log.debug("Removing peer with URI: {}", peerUri);
        //remove(peerUri, this.establishedPeerProxies);
    }

    private void removeAnonymousPeerUri(final URI peerUri) {
        log.debug("Removing anonymous peer with URI: {}", peerUri);
        //remove(peerUri, this.establishedAnonymousProxies);
    }

    private void remove(final URI peerUri, final Queue<URI> queue) {
        log.debug("Removing peer with URI: {}", peerUri);
        queue.remove(peerUri);
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
    public boolean hasProxy() {
        return !this.proxies.isEmpty();
    }

    @Subscribe
    public void onReset(final ResetEvent event) {
        clear();
    }

    @Override
    public void stop() {
        for (final GlobalTrafficShapingHandler handler : this.trafficShapers) {
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

}
