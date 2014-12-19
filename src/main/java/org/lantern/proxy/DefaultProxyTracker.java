package org.lantern.proxy;

import static org.littleshoot.util.FiveTuple.Protocol.*;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Date;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import org.apache.commons.codec.digest.DigestUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.lantern.ConnectivityStatus;
import org.lantern.LanternTrustStore;
import org.lantern.PeerFactory;
import org.lantern.S3Config;
import org.lantern.event.Events;
import org.lantern.event.ModeChangedEvent;
import org.lantern.event.ProxyConnectionEvent;
import org.lantern.event.ResetEvent;
import org.lantern.event.WaddellPeerAvailabilityEvent;
import org.lantern.kscope.ReceivedKScopeAd;
import org.lantern.network.InstanceInfo;
import org.lantern.network.NetworkTracker;
import org.lantern.network.NetworkTrackerListener;
import org.lantern.state.Model;
import org.lantern.state.Peer;
import org.lantern.state.PeerType;
import org.lantern.state.SyncPath;
import org.lantern.util.Hashed;
import org.lantern.util.Threads;
import org.littleshoot.util.FiveTuple.Protocol;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.collect.ImmutableList;
import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class for keeping track of all proxies we know about.
 */
@Singleton
public class DefaultProxyTracker implements ProxyTracker, NetworkTrackerListener<URI, ReceivedKScopeAd> {

    private static final Logger LOG = LoggerFactory
            .getLogger(DefaultProxyTracker.class);

    // Tracks proxies in the current configuration, used to identify when the
    // configuration has changed.
    private final Set<ProxyInfo> configuredProxies = new HashSet<ProxyInfo>();
    
    /**
     * Holds all proxies.
     */
    private final Set<ProxyHolder> proxies = Collections
            .synchronizedSet(new HashSet<ProxyHolder>());

    private final Model model;

    private final PeerFactory peerFactory;

    private ScheduledExecutorService proxyRetryService;

    private final LanternTrustStore lanternTrustStore;
    
    /**
     * We offload TCP connections to a thread to avoid callers waiting on
     * potentially slow connections to peers.
     */
    private final ExecutorService proxyConnect = 
            Threads.newCachedThreadPool("Proxy-Connect-Thread-");
    
    @Inject
    public DefaultProxyTracker(
            final Model model,
            final PeerFactory peerFactory,
            final LanternTrustStore lanternTrustStore,
            final NetworkTracker<String, URI, ReceivedKScopeAd> networkTracker) {
        this.model = model;
        this.peerFactory = peerFactory;
        this.lanternTrustStore = lanternTrustStore;
        networkTracker.addListener(this);
        
        Events.register(this);
    }
    
    @Override
    public void init() {
        onNewS3Config(this.model.getS3Config());
        restoreDeceasedProxies();
    }
    
    @Override
    public void start() {
        LOG.debug("Starting...");
        proxyRetryService = Threads
                .newScheduledThreadPool("Proxy-Retry");
        // Periodically restore timed in proxies
        proxyRetryService.scheduleWithFixedDelay(new Runnable() {
            @Override
            public void run() {
                restoreTimedInProxies();
            }
        }, 100, 100, TimeUnit.MILLISECONDS);
    }
    
    @Override
    public void stop() {
        LOG.debug("Stopping...");
        // The proxyRetryService could be null if we haven't started yet.
        if (proxyRetryService != null) {
            proxyRetryService.shutdownNow();
        }
    }

    @Subscribe
    public void onNewS3Config(final S3Config config) {
        Set<ProxyInfo> newFallbacks = new HashSet<ProxyInfo>(config.getAllFallbacks());
        Set<ProxyInfo> removed = new HashSet<ProxyInfo>();
        
        LOG.info("Processing new S3Config with {} fallbacks", newFallbacks.size());
        synchronized (configuredProxies) {
            // Remove proxies from configuration that are no longer in the S3 config
            Iterator<ProxyInfo> it = configuredProxies.iterator();
            while (it.hasNext()) {
                ProxyInfo info = it.next();
                if (info.getType() == PeerType.cloud
                        && !newFallbacks.contains(info)) {
                    LOG.info("Removing proxy from configuration: {}", info);
                    it.remove();
                    removed.add(info);
                }
            }
        }
        synchronized (proxies) {
            // Remove proxies that are no longer configured
            Iterator<ProxyHolder> it = proxies.iterator();
            while (it.hasNext()) {
                ProxyHolder proxy = it.next();
                if (removed.contains(proxy.getInfo())) {
                    LOG.info("Removing proxy from rotation: {}", proxy);
                    it.remove();
                    proxy.stopPtIfNecessary();
                }
            }
        }
        addFallbackProxies(config);
        
        LOG.info("Done processing new S3Config with {} fallbacks", newFallbacks.size());
    }
    
    @Override
    public void instanceOnlineAndTrusted(
            InstanceInfo<URI, ReceivedKScopeAd> instance) {
        LOG.debug("Adding proxy... {}", instance);
        ReceivedKScopeAd ad = instance.getData();
        if (ad.getAd().getWaddellId() != null) {
            LOG.debug("Adding waddell peer {} with id {} at {}",
                    ad.getFrom(),
                    ad.getAd().getWaddellId(),
                    ad.getAd().getWaddellAddr());
            Events.asyncEventBus().post(WaddellPeerAvailabilityEvent.available(
                    hashJid(ad.getFrom()),
                    ad.getAd().getWaddellId(),
                    ad.getAd().getWaddellAddr(),
                    model.getLocation().getCountry()));
        }
        if (instance.hasMappedEndpoint()) {
            final ProxyInfo info = instance.getData().getAd().getProxyInfo();
            
            if (info != null) {
                addProxy(info);
                // Also add the local network advertisement in case they're on
                // the local network.
                addProxy(info.onLan());
            }
        }
    }
    
    @Override
    public void instanceOfflineOrUntrusted(
            InstanceInfo<URI, ReceivedKScopeAd> instance) {
        URI jid = instance.getId();
        LOG.debug("Removing proxy for {}", jid);
        removeNattedProxy(jid);
        LOG.debug("Removing waddell peer {}", jid);
        Events.asyncEventBus().post(
                WaddellPeerAvailabilityEvent.unavailable(
                        hashJid(jid.toString())));
    }

    @Override
    public void clear() {
        synchronized (proxies) {
            for (ProxyHolder proxy : proxies) {
                proxy.stopPtIfNecessary();
            }
        }
        proxies.clear();

        // We need to add the fallback proxy back in.
        addFallbackProxies(this.model.getS3Config());
    }

    @Override
    public void clearPeerProxySet() {
        synchronized (proxies) {
            Iterator<ProxyHolder> it = proxies.iterator();
            while (it.hasNext()) {
                if (it.next().isNatTraversed()) {
                    it.remove();
                }
            }
        }
    }

    @Override
    public void addProxy(final ProxyInfo info) {
        synchronized (configuredProxies) {
            if (configuredProxies.contains(info)) {
                LOG.debug("Proxy already configured.  Configured proxies is: {}", configuredProxies);
                return;
            }
            configuredProxies.add(info);
        }
        InetAddress remoteAddress = null;
        if (info != null && info.wanAddress() != null) {
            remoteAddress = info.wanAddress().getAddress();
        }
        if (remoteAddress != null) {
            if (remoteAddress.isLoopbackAddress()
                    || remoteAddress.isAnyLocalAddress()) {
                LOG.warn(
                        "Can connect to neither loopback nor 0.0.0.0 address {}",
                        remoteAddress);
                info.setWanHost(null);
                info.setWanPort(0);
            }
        }
        ProxyHolder proxy = new ProxyHolder(this, peerFactory,
                lanternTrustStore, info);
        doAddProxy(proxy);
    }

    @Override
    public void removeNattedProxy(final URI uri) {
        synchronized (this.proxies) {
            Iterator<ProxyHolder> it = proxies.iterator();
            while (it.hasNext()) {
                ProxyHolder proxy = it.next();
                if (proxy.getJid().equals(uri) && proxy.isNatTraversed()) {
                    LOG.debug("Removing peer by request: {}", uri);
                    it.remove();
                }
            }
        }
    }

    @Override
    public void onCouldNotConnect(final ProxyHolder proxy) {
        LOG.info("Could not connect!!");
        
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
        LOG.info("Error on peer {}", peerUri);
        synchronized (proxies) {
            for (ProxyHolder proxy : proxies) {
                if (proxy.getJid().equals(peerUri)) {
                    proxy.failedToConnect();
                }
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

    @Subscribe
    public void onModeChanged(final ModeChangedEvent event) {
        LOG.debug("Received mode changed event: {}", event);
        addFallbackProxies(this.model.getS3Config());
    }

    @Override
    public Collection<ProxyHolder> getConnectedProxiesInOrderOfFallbackPreference() {
        List<ProxyHolder> result = new ArrayList<ProxyHolder>();
        synchronized (this.proxies) {
            for (ProxyHolder proxy : proxies) {
                if (proxy.isConnected()) {
                    result.add(proxy);
                }
            }
        }
        Collections.sort(result, 
                new ProxyPrioritizer(this.model.getSettings().getUdpProxyPriority()));
        return ImmutableList.copyOf(result);
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

    private void doAddProxy(final ProxyHolder proxy) {
        LOG.info("Adding proxy {} {}", proxy.getJid(), proxy);
        
        synchronized (proxies) {
            // We need to remove the old proxy that may match the base JID and
            // IP/port pair of this new proxy and replace it with all the new
            // info. This will overwrite any connection retry data, for example,
            // and will ensure that we don't have duplicate entries for the
            // same remote peer on the same machine.
            proxies.remove(proxy);
            proxies.add(proxy);
            LOG.info("Proxies is now {}", proxies);
        }
        if (proxy.getType() == PeerType.cloud) {
            // Assume cloud proxies to be connected
            successfullyConnectedToProxy(proxy);
        } else {
            checkConnectivityToProxy(proxy);
        }

    }

    private void checkConnectivityToProxy(ProxyHolder proxy) {
        if (proxy.isNatTraversed()) {
            // NAT traversed UDP proxies are currently disabled
            // checkConnectivityToNattedProxy(proxy);
        } else {
            if (proxy.getType() == PeerType.cloud) {
                // Assume cloud proxies to be connected
                
                // Make sure our bookkeeping is in order, particularly our
                // nproxies count.
                successfullyConnectedToProxy(proxy);
            } else if (proxy.getFiveTuple().getProtocol() == TCP) {
                checkConnectivityToTcpProxy(proxy);
            } else {
                // TODO: need to actually test UDT connectivity somehow
                successfullyConnectedToProxy(proxy);
            }
        }
    }
    

    /**
     * Threaded connectivity check to peer TCP proxies to avoid callers
     * unexpectedly blocking on checks for as much as the socket connect
     * timeout.
     * 
     * @param proxy The proxy to check.
     */
    private void checkConnectivityToTcpProxy(final ProxyHolder proxy) {
        proxyConnect.submit(new Runnable() {

            @Override
            public void run() {
                final Socket sock = new Socket();
                final InetSocketAddress remote = proxy.getFiveTuple()
                        .getRemote();
                try {
                    sock.connect(remote, 60 * 1000);
                    successfullyConnectedToProxy(proxy);
                } catch (final IOException e) {
                    // This can happen if the user has subsequently gone
                    // offline, for example.
                    LOG.debug("Could not connect to proxy: {}", proxy, e);
                    onCouldNotConnect(proxy);

                    if (proxy.attemptNatTraversalIfConnectionFailed()) {
                        addProxy(new ProxyInfo(proxy.getJid(), 1000));
                    }
                } finally {
                    IOUtils.closeQuietly(sock);
                }
            }
        });
    }

    /**
     * Let the world know that we've successfully connected to the proxy.
     * 
     * @param proxy The proxy we connected.
     */
    private void successfullyConnectedToProxy(ProxyHolder proxy) {
        final InetSocketAddress isa = proxy.getFiveTuple().getRemote();
        final URI fullJid =  proxy.getJid();
        LOG.debug("Connected to proxy: {}", proxy);
        peerFactory.onOutgoingConnection(proxy.getJid(), isa, proxy.getType());
        proxy.markConnected();

        LOG.debug("Dispatching CONNECTED event");
        Events.asyncEventBus().post(
                new ProxyConnectionEvent(ConnectivityStatus.CONNECTED));

        notifyProxiesSize();
        
        /* do geolocation now that we've registered a proxy */
        final Peer peer = this.model.getPeerCollector().getPeer(fullJid);
        peerFactory.updateGeoData(peer, isa.getAddress());
    }

    private void notifyProxiesSize() {
        int numberOfConnectedProxies = 0;
        synchronized (proxies) {
            LOG.debug("Proxies are: {}", proxies);
            for (ProxyHolder proxy : proxies) {
                if (proxy.isConnected()) {
                    numberOfConnectedProxies += 1;
                }
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
        synchronized (proxies) {
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
    }

    private void restoreDeceasedProxies() {
        synchronized (proxies) {
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
    }

    private void addFallbackProxies(final S3Config config) {
        if (config == null) {
            LOG.debug("Ignoring null config");
            return;
        }
        LOG.debug("Attempting to add fallback proxies");
        for (final FallbackProxy fp : config.getAllFallbacks()) {
            addSingleFallbackProxy(fp);
        }
    }

    @Override
    public void addSingleFallbackProxy(FallbackProxy fallbackProxy) {
        LOG.debug("Attempting to add single fallback proxy: {}", fallbackProxy);

        final String cert = fallbackProxy.getCert();
        if (StringUtils.isNotBlank(cert)) {
            lanternTrustStore.addCert(cert);
        } else {
            // Likely flashlight -- the cert is handled internally there.
            LOG.debug("Fallback with no cert? {}", fallbackProxy);
        }
        final Peer cloud = this.peerFactory.addPeer(fallbackProxy.getJid(), PeerType.cloud);
        cloud.setMode(org.lantern.state.Mode.give);

        LOG.debug("Adding fallback: {}", fallbackProxy.getWanHost());
        addProxy(fallbackProxy);
    }

    private String hashJid(String jid) {
        try {
            // We hash the peer ID so as to avoid exposing it in the
            // flashlight.yaml. We salt it with the instance id.
            MessageDigest digest = DigestUtils.getSha256Digest();
            digest.update(model.getInstanceId().getBytes());
            return new Hashed(model.getInstanceId().getBytes(),
                    jid.getBytes(),
                    2000).hashHex();
        } catch (Exception e) {
            throw new RuntimeException(String.format(
                    "Unable to encrypt JID: ", e.getMessage()),
                    e);
        }
    }
}