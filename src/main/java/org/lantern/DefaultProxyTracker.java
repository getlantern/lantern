package org.lantern;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.util.HashSet;
import java.util.Queue;
import java.util.Set;
import java.util.concurrent.ConcurrentLinkedQueue;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.lantern.event.Events;
import org.lantern.event.ResetEvent;
import org.lantern.state.Model;
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
    private final Set<URI> peerProxySet = new HashSet<URI>();
    
    private final Set<ProxyHolder> laeProxySet =
        new HashSet<ProxyHolder>();
    private final Queue<ProxyHolder> laeProxies = 
        new ConcurrentLinkedQueue<ProxyHolder>();

    private final TrustedPeerProxyManager trustedPeerProxyManager;

    private final Model model;
    
    @Inject
    public DefaultProxyTracker(final Model model,
        final TrustedPeerProxyManager trustedPeerProxyManager) {
        this.model = model;
        this.trustedPeerProxyManager = trustedPeerProxyManager;
        Events.register(this);
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
    }
    

    @Override
    public void clearPeerProxySet() {
        this.peerProxySet.clear();
    }
    
    
    @Override
    public boolean addPeerProxy(final URI peerUri) {
        log.info("Considering peer proxy");
        synchronized (peerProxySet) {
            // We purely do this to keep track of which peers we've attempted
            // to establish connections to. This is to avoid exchanging certs
            // multiple times.
            
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
        log.info("Adding LAE proxy");
        addProxyWithChecks(this.laeProxySet, this.laeProxies, 
            new ProxyHolder(cur, new InetSocketAddress(cur, 443)), cur);
    }
    
    @Override
    public void addGeneralProxy(final String cur) {
        final String hostname = StringUtils.substringBefore(cur, ":");
        final int port = Integer.parseInt(StringUtils.substringAfter(cur, ":"));
        final InetSocketAddress isa = new InetSocketAddress(hostname, port);
        addProxyWithChecks(proxySet, proxies, new ProxyHolder(hostname, isa), 
            cur);
    }
    
    private InetSocketAddress getProxy(final Queue<ProxyHolder> queue) {
        synchronized (queue) {
            if (queue.isEmpty()) {
                log.info("No proxy addresses");
                return null;
            }
            final ProxyHolder proxy = queue.remove();
            queue.add(proxy);
            log.info("FIFO queue is now: {}", queue);
            return proxy.isa;
        }
    }
    
    private void addProxyWithChecks(final Set<ProxyHolder> set,
        final Queue<ProxyHolder> queue, final ProxyHolder ph, 
        final String fullProxyString) {
        if (set.contains(ph)) {
            log.info("We already know about proxy "+ph+" in {}", set);
            
            // Send the event again in case we've somehow gotten into the 
            // wrong state.
            log.info("Dispatching CONNECTED event");
            return;
        }
        
        final Socket sock = new Socket();
        try {
            sock.connect(ph.isa, 60*1000);
            log.info("Dispatching CONNECTED event");
            
            // This is a little odd because the proxy could have originally
            // come from the settings themselves, but it'll remove duplicates,
            // so no harm done.
            this.model.getSettings().addProxy(fullProxyString);
            synchronized (set) {
                if (!set.contains(ph)) {
                    set.add(ph);
                    queue.add(ph);
                    log.info("Queue is now: {}", queue);
                }
            }
        } catch (final IOException e) {
            log.error("Could not connect to: {}", ph);
            onCouldNotConnect(ph.isa);
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
            trustedPeerProxyManager.removePeer(uri);
        //} else {
        //    LanternHub.anonymousPeerProxyManager().removePeer(uri);
        //}
    }
    
    private void removePeerUri(final URI peerUri) {
        log.info("Removing peer with URI: {}", peerUri);
        //remove(peerUri, this.establishedPeerProxies);
    }

    private void removeAnonymousPeerUri(final URI peerUri) {
        log.info("Removing anonymous peer with URI: {}", peerUri);
        //remove(peerUri, this.establishedAnonymousProxies);
    }
    
    private void remove(final URI peerUri, final Queue<URI> queue) {
        log.info("Removing peer with URI: {}", peerUri);
        queue.remove(peerUri);
    }
    
    @Override
    public InetSocketAddress getLaeProxy() {
        return getProxy(this.laeProxies);
    }
    
    @Override
    public InetSocketAddress getProxy() {
        return getProxy(this.proxies);
    }
    
    
    @Subscribe
    public void onReset(final ResetEvent event) {
        clear();
    }

    private static final class ProxyHolder {
        
        private final String id;
        private final InetSocketAddress isa;

        private ProxyHolder(final String id, final InetSocketAddress isa) {
            this.id = id;
            this.isa = isa;
        }
        
        @Override
        public String toString() {
            return "ProxyHolder [isa=" + isa + "]";
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
            if (id == null) {
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

}
