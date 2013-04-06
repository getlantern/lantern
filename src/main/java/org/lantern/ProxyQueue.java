package org.lantern;

import java.util.Date;
import java.util.HashSet;
import java.util.Queue;
import java.util.Set;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.PriorityBlockingQueue;

import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ProxyQueue {

    private final Logger log = LoggerFactory.getLogger(getClass());

    /**
     * These are the proxies this Lantern instance is using that can be directly
     * connected to.
     *
     */
    protected final Set<ProxyHolder> proxySet = new HashSet<ProxyHolder>();
    protected final Queue<ProxyHolder> proxies = new ConcurrentLinkedQueue<ProxyHolder>();

    /**
     * Proxies that have failed and thus are timed out, ordered by the time that
     * they will time back in
     */
    protected final PriorityBlockingQueue<ProxyHolder> pausedProxies = new PriorityBlockingQueue<ProxyHolder>();

    private final Model model;

    private boolean weHaveInternet;

    ProxyQueue(Model model) {
        this.model = model;
    }

    public synchronized boolean add(ProxyHolder holder) {
        if (proxySet.contains(holder))
            return false;
        proxySet.add(holder);
        proxies.add(holder);
        return true;
    }

    public synchronized ProxyHolder getProxy() {
        if (model.getConnectivity().isInternet()) {
            log.debug("Internet connected");
            weHaveInternet = true;
        } else {
            if (weHaveInternet) {
                log.debug("First time with no internet connection");
                // we have just learned that in fact we don't
                weHaveInternet = false;
                // restore recently-deceased proxies (since they probably died
                // of general internet failure
                restoreRecentlyDeceasedProxies();
            }
        }
        restoreTimedInProxies();

        if (proxies.isEmpty()) {
            log.debug("No proxy addresses -- " + pausedProxies.size()
                    + " paused");
            return null;
        }
        final ProxyHolder proxy = proxies.remove();
        reenqueueProxy(proxy);
        log.debug("FIFO queue is now: {}", proxies);
        return proxy;
    }

    protected void reenqueueProxy(final ProxyHolder proxy) {
        proxies.add(proxy);
    }

    private void restoreRecentlyDeceasedProxies() {
        synchronized (pausedProxies) {
            long now = new Date().getTime();
            while (true) {
                final ProxyHolder proxy = pausedProxies.peek();
                if (proxy == null)
                    break;
                if (now - proxy.getTimeOfDeath() < 60 * 1000) {
                    pausedProxies.remove();
                    log.debug("Restoring " + proxy);
                    proxy.resetFailures();
                    reenqueueProxy(proxy);
                } else {
                    break;
                }
            }
        }
    }

    private void restoreTimedInProxies() {
        long now = new Date().getTime();
        while (true) {
            ProxyHolder proxy = pausedProxies.peek();
            if (proxy == null)
                break;
            if (now > proxy.getRetryTime()) {
                log.debug("Restoring timed-in proxy " + proxy);
                reenqueueProxy(proxy);
                pausedProxies.remove();
            } else {
                break;
            }
        }
    }

    public synchronized void proxyFailed(ProxyHolder proxyAddress) {
        if (model.getConnectivity().isInternet()) {
            proxies.remove(proxyAddress);
            proxyAddress.addFailure();
            if (!pausedProxies.contains(proxyAddress)) {
                pausedProxies.add(proxyAddress);
            }
        } else {
            log.info("No internet connection, so don't mark off proxies");
        }
    }

    public synchronized void removeProxy(ProxyHolder proxyAddress) {
        proxySet.remove(proxyAddress);
        proxies.remove(proxyAddress);
        pausedProxies.remove(proxyAddress);
    }

    public boolean isEmpty() {
        return proxies.isEmpty();
    }

    public synchronized void clear() {
        proxySet.clear();
        proxies.clear();
        pausedProxies.clear();
    }

    public boolean contains(ProxyHolder ph) {
        return proxySet.contains(ph);
    }

}
