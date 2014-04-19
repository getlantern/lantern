package org.lantern.proxy;

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
import java.util.Properties;
import java.util.Set;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.ReentrantLock;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.lantern.ConnectivityChangedEvent;
import org.lantern.ConnectivityStatus;
import org.lantern.LanternTrustStore;
import org.lantern.LanternUtils;
import org.lantern.PeerFactory;
import org.lantern.S3Config;
import org.lantern.event.Events;
import org.lantern.event.ModeChangedEvent;
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

    private final Set<ProxyInfo> configuredProxies = new HashSet<ProxyInfo>();
    
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
                p.stopPtIfNecessary();
            }
        }
        proxies.removeAll(fallbacks);
        Iterator<ProxyInfo> it = configuredProxies.iterator();
        while (it.hasNext()) {
            ProxyInfo info = it.next();
            if (info.getType() == Type.cloud) {
                it.remove();
            }
        }
        
        
        config.getFallbacks().clear();
        config.getFallbacks().add(flashlightProxy());
        addFallbackProxies(config);
    }

    @Override
    public void clear() {
        for (ProxyHolder proxy : proxies) {
            proxy.stopPtIfNecessary();
        }
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
    public void addProxy(ProxyInfo info) {
        synchronized (this) {
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

    @Subscribe
    public void onModeChanged(final ModeChangedEvent event) {
        LOG.debug("Received mode changed event: {}", event);
        addFallbackProxies(this.model.getS3Config());
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

    private void doAddProxy(final ProxyHolder proxy) {
        LOG.info("Adding proxy {} {}", proxy.getJid(), proxy);
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

    private void checkConnectivityToProxy(ProxyHolder proxy) {
        if (proxy.isNatTraversed()) {
            // NAT traversed UDP proxies are currently disabled
            // checkConnectivityToNattedProxy(proxy);
        } else {
            if (proxy.getType() == Peer.Type.cloud) {
                // Assume cloud proxies to be connected
                proxy.markConnected();
            } else if (proxy.getFiveTuple().getProtocol() == TCP) {
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
                addProxy(new ProxyInfo(proxy.getJid()));
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
        final URI uri = LanternUtils.newURI("fallback-" + fallbackProxy.getWanHost()
                + "@getlantern.org");
        fallbackProxy.setJid(uri);
        final Peer cloud = this.peerFactory.addPeer(uri, Type.cloud);
        cloud.setMode(org.lantern.state.Mode.give);

        LOG.debug("Adding fallback: {}", fallbackProxy.getWanHost());
        addProxy(fallbackProxy);
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
    
    private FallbackProxy flashlightProxy() {
        FallbackProxy flashlightProxy = new FallbackProxy();
        flashlightProxy.pt = new Properties();
        flashlightProxy.pt.setProperty("type", "flashlight");
        flashlightProxy.setIp("cdnjs.com");
        flashlightProxy.setPort(443);
        flashlightProxy.setProtocol(Protocol.TCP);
        // The below is the PEM-encoded certificate for cdnjs.com
        //@formatter:off
        flashlightProxy.setCert("-----BEGIN CERTIFICATE-----\n" +
"MIIHbTCCBlWgAwIBAgISESHGdSbqDfRsZ0676qVKIcRrMA0GCSqGSIb3DQEBBQUA\n" +
"MF0xCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTMwMQYD\n" +
"VQQDEypHbG9iYWxTaWduIE9yZ2FuaXphdGlvbiBWYWxpZGF0aW9uIENBIC0gRzIw\n" +
"HhcNMTQwNDE2MDA1NzU0WhcNMTYxMDEzMTg0NDUzWjBuMQswCQYDVQQGEwJVUzEL\n" +
"MAkGA1UECBMCQ0ExFjAUBgNVBAcTDVNhbiBGcmFuY2lzY28xGTAXBgNVBAoTEENs\n" +
"b3VkRmxhcmUsIEluYy4xHzAdBgNVBAMTFnNzbDIyMjIuY2xvdWRmbGFyZS5jb20w\n" +
"ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDfg3IEsINBN6bGKaDXGeu1\n" +
"d8rR/mO5he8xnCTyZ6t4sJONRC0N2WrkFfaoQvDAu2SLxDG6kLmQBLvNQkqVzT1d\n" +
"KEsoyKlio7/PFIRL8ssuYgt5rQRqqGFUikc8TG5igiKetzrzQdXbrXknMRluu7nI\n" +
"KVGzLW8p4ugGzAU8GR3boiHwYmw7a7MvCgD2+jyeiYQHxh/pEwkQFr1lEXo3B/5x\n" +
"eHzgFU8FybnK0uGf5BykZVfVaZqjnQdGwOGBc46tlMd1HeSXkVSiFKmzuIsZblqn\n" +
"AYX01FiydKmULZWwCCVqop89AXFBZYNSi36ZQ+KHn7kOD679mRcgpTRhOMIyxoxR\n" +
"AgMBAAGjggQUMIIEEDAOBgNVHQ8BAf8EBAMCBaAwSQYDVR0gBEIwQDA+BgZngQwB\n" +
"AgIwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVw\n" +
"b3NpdG9yeS8wggJnBgNVHREEggJeMIICWoIWc3NsMjIyMi5jbG91ZGZsYXJlLmNv\n" +
"bYIbKi5wcmVtaXVtLWFjdGl2ZS1rZXRvbmUuY29tghlwcmVtaXVtLWFjdGl2ZS1r\n" +
"ZXRvbmUuY29tggljZG5qcy5jb22CDSouYmV0dGluZy5jb22CDG5nZWZvcnVtLm9y\n" +
"Z4ILYWJldGEuY28udWuCHyouYWN0aXZlLXJhc3BiZXJyeWtldG9uZXMuY28udWuC\n" +
"DSouYmlvdG9wcy5iaXqCC2Jpb3RvcHMuYml6gg4qLm5ldHdvcmswMS5zb4ILa2li\n" +
"dS5jb20uYXWCDSoua2lidS5jb20uYXWCDCouY3VydGluYS5mcoIKY3VydGluYS5m\n" +
"coIMd2lzaGJlcmcuY29tgh1hY3RpdmUtcmFzcGJlcnJ5a2V0b25lcy5jby51a4IU\n" +
"Ki5maWx0ZXJ5b3VybGlmZS5jb22CEmZpbHRlcnlvdXJsaWZlLmNvbYIRKi5zb2tl\n" +
"cmlsYXV0YS5vcmeCDSouYWJldGEuY28udWuCDioubmdlZm9ydW0ub3JnghQqLmxv\n" +
"cmRvZnRoZWNyYWZ0Lm5ldIINbXUtdWNoaWhhLmJpeoISbG9yZG9mdGhlY3JhZnQu\n" +
"bmV0gg9zb2tlcmlsYXV0YS5vcmeCDyoubXUtdWNoaWhhLmJpeoIOKi53aXNoYmVy\n" +
"Zy5jb22CGioubXktb3JnYW5pYy1jbGVhbnNlLmNvLnVrghhteS1vcmdhbmljLWNs\n" +
"ZWFuc2UuY28udWuCDG5ldHdvcmswMS5zb4ILKi5jZG5qcy5jb22CC2JldHRpbmcu\n" +
"Y29tMAkGA1UdEwQCMAAwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMEUG\n" +
"A1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5jb20vZ3MvZ3Nv\n" +
"cmdhbml6YXRpb252YWxnMi5jcmwwgZYGCCsGAQUFBwEBBIGJMIGGMEcGCCsGAQUF\n" +
"BzAChjtodHRwOi8vc2VjdXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc29yZ2Fu\n" +
"aXphdGlvbnZhbGcyLmNydDA7BggrBgEFBQcwAYYvaHR0cDovL29jc3AyLmdsb2Jh\n" +
"bHNpZ24uY29tL2dzb3JnYW5pemF0aW9udmFsZzIwHQYDVR0OBBYEFKc3TefWQCgJ\n" +
"a/rSff1ni4rsrFlhMB8GA1UdIwQYMBaAFF1Gso3ES3Qcu+31c7Y6tziPdZ5+MA0G\n" +
"CSqGSIb3DQEBBQUAA4IBAQAOOSeL7I8Dxq1ZxkhnNMLwb9XOtPk4osAZQntUN1NV\n" +
"OmQU4x1hhFfV/Su4TykbvKAIt152W3cQs2fzS/QRhYooVu2JnI9chAd1kCc6KBfI\n" +
"de/FvQtgbIhlUAhrfwyj6pvKuqk0onFeU8d7W7Thpq9LwKb29S13zmsZ9d3Dttl9\n" +
"oBBtLJiHX/WaUazba7+cEbof2QHkeJ6ztqp/ALT9cG1POunhy+EqKpSYuEIV8pnA\n" +
"nlteNCWPz8IrlNNNG8fvxiGYz8K47dlz73vXG3yIye0iSJU8D7CS+OIJErceDRcb\n" +
"lve37aX4z+LmJyUoiVRJfC+T2+Rms472xBB3jvyD+0Gk\n" +
"-----END CERTIFICATE-----");
      //@formatter:on
        return flashlightProxy;
    }
}
