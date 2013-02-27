package org.lantern;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.Queue;
import java.util.Set;
import java.util.concurrent.ConcurrentLinkedQueue;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.jboss.netty.handler.traffic.GlobalTrafficShapingHandler;
import org.jboss.netty.util.Timer;
import org.lantern.event.Events;
import org.lantern.event.ProxyConnectionEvent;
import org.lantern.event.ResetEvent;
import org.lantern.state.Model;
import org.lantern.state.Peer.Type;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class for keeping track of all proxies we know about.
 */
@Singleton
public class DefaultProxyTracker implements ProxyTracker, Shutdownable {

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

    @Inject
    public DefaultProxyTracker(final Model model,
        final PeerProxyManager trustedPeerProxyManager,
        final PeerFactory peerFactory, final org.jboss.netty.util.Timer timer) {
        this.model = model;
        this.peerProxyManager = trustedPeerProxyManager;
        this.peerFactory = peerFactory;
        this.timer = timer;
        
        addFallbackProxy();
        Events.register(this);
    }

    private void addFallbackProxy() {
        addProxy(LanternConstants.FALLBACK_SERVER_HOST, 
            Integer.parseInt(LanternConstants.FALLBACK_SERVER_PORT), Type.cloud);
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
        log.info("Considering peer proxy");
        synchronized (peerProxySet) {
            // TODO: I believe this excludes exchanging keys with peers who
            // are on multiple machines when the peer URI is a general JID and
            // not an instance JID.
            if (!peerProxySet.contains(peerUri)) {
                log.info("Actually adding peer proxy: {}", peerUri);
                peerProxySet.add(peerUri);
                return true;
            } else {
                log.info("We already know about the peer proxy");
            }
        }
        return false;
    }


    @Override
    public void addLaeProxy(final String cur) {
        log.debug("Adding LAE proxy");
        addProxyWithChecks(this.laeProxySet, this.laeProxies,
            new ProxyHolder(cur, new InetSocketAddress(cur, 443), trafficTracker()), cur, 
            Type.laeproxy);
    }
    
    private Collection<GlobalTrafficShapingHandler> trafficShapers =
            new ArrayList<GlobalTrafficShapingHandler>();
    
    private GlobalTrafficShapingHandler trafficTracker() {
        final GlobalTrafficShapingHandler handler = 
            new GlobalTrafficShapingHandler(this.timer, 1000);
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

        final Socket sock = new Socket();
        try {
            sock.connect(ph.getIsa(), 60*1000);
            log.debug("Dispatching CONNECTED event");
            Events.asyncEventBus().post(
                new ProxyConnectionEvent(ConnectivityStatus.CONNECTED));
            // This is a little odd because the proxy could have originally
            // come from the settings themselves, but it'll remove duplicates,
            // so no harm done.
            log.debug("Adding proxy to settings: {}", this.model.getSettings());
            this.model.getSettings().addProxy(fullProxyString);
            
            this.peerFactory.addPeer("", ph.getIsa().getAddress(), 
                ph.getIsa().getPort(), type, false, 
                ph.getTrafficShapingHandler().getTrafficCounter());
            synchronized (set) {
                if (!set.contains(ph)) {
                    set.add(ph);
                    queue.add(ph);
                    log.debug("Queue is now: {}", queue);
                }
            }
        } catch (final IOException e) {
            log.error("Could not connect to: {}", ph);
            onCouldNotConnect(ph.getIsa());
            this.model.getSettings().removeProxy(fullProxyString);
        } finally {
            IOUtils.closeQuietly(sock);
        }
    }

    @Override
    public void onCouldNotConnect(final InetSocketAddress proxyAddress) {
        // This can happen in several scenarios. First, it can happen if you've
        // actually disconnected from the internet. Second, it can happen if
        // the proxy is blocked. Third, it can happen when the proxy is simply
        // down for some reason.
        log.info("COULD NOT CONNECT TO STANDARD PROXY!! Proxy address: {}",
            proxyAddress);

        // For now we assume this is because we've lost our connection.
        //onCouldNotConnect(new ProxyHolder(proxyAddress.getHostName(), proxyAddress),
        //    this.proxySet, this.proxies);
    }

    @Override
    public void onCouldNotConnectToLae(final InetSocketAddress proxyAddress) {
        log.info("COULD NOT CONNECT TO LAE PROXY!! Proxy address: {}",
            proxyAddress);

        // For now we assume this is because we've lost our connection.

        //onCouldNotConnect(new ProxyHolder(proxyAddress.getHostName(), proxyAddress),
        //    this.laeProxySet, this.laeProxies);
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


    @Subscribe
    public void onReset(final ResetEvent event) {
        clear();
    }

    public static final class ProxyHolder {

        private final String id;
        private final InetSocketAddress isa;
        private final GlobalTrafficShapingHandler trafficShapingHandler;

        private ProxyHolder(final String id, final InetSocketAddress isa, 
            final GlobalTrafficShapingHandler trafficShapingHandler) {
            this.id = id;
            this.isa = isa;
            this.trafficShapingHandler = trafficShapingHandler;
        }

        public String getId() {
            return id;
        }

        public InetSocketAddress getIsa() {
            return isa;
        }
        
        public GlobalTrafficShapingHandler getTrafficShapingHandler() {
            return trafficShapingHandler;
        }
        
        @Override
        public String toString() {
            return "ProxyHolder [isa=" + getIsa() + "]";
        }

        @Override
        public int hashCode() {
            final int prime = 31;
            int result = 1;
            result = prime * result + ((id == null) ? 0 : id.hashCode());
            result = prime * result + ((isa == null) ? 0 : isa.hashCode());
            return result;
        }

        @Override
        public boolean equals(Object obj) {
            if (this == obj)
                return true;
            if (obj == null)
                return false;
            if (getClass() != obj.getClass())
                return false;
            ProxyHolder other = (ProxyHolder) obj;
            if (getId() == null) {
                if (other.id != null)
                    return false;
            } else if (!id.equals(other.id))
                return false;
            if (isa == null) {
                if (other.isa != null)
                    return false;
            } else if (!isa.equals(other.isa))
                return false;
            return true;
        }
    }

    @Override
    public void stop() {
        for (final GlobalTrafficShapingHandler handler : this.trafficShapers) {
            handler.releaseExternalResources();
        }
    }

}
