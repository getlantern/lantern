package org.lantern;

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

    ProxyQueue(Model model) {
        this.model = model;
    }

    public synchronized boolean add(ProxyHolder holder) {
        if (proxySet.contains(holder)) {
            if (!holder.isConnected()) {
                holder.resetFailures();
                proxies.add(holder);
                return true;
            }
            return false;
        }
        proxySet.add(holder);
        proxies.add(holder);
        return true;
    }

    public synchronized ProxyHolder getProxy() {
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


    public synchronized void proxyFailed(ProxyHolder proxyAddress) {
        //this actually might be the first time we see a proxy, if
        //the initial connection fails
        if (!proxySet.contains(proxyAddress)) {
            proxySet.add(proxyAddress);
        }
        if (model.getConnectivity().isInternet()) {
            proxies.remove(proxyAddress);
            proxyAddress.addFailure();
            if (!pausedProxies.contains(proxyAddress)) {
                pausedProxies.add(proxyAddress);
            }
        } else {
            log.info("No internet connection, so don't mark off proxies");
            //but do re-add it to the paused list, if necessary
            if (!proxies.contains(proxyAddress)) {
                if (!pausedProxies.contains(proxyAddress)) {
                    log.debug("Adding a paused proxy");
                    pausedProxies.add(proxyAddress);
                }
            } else {
                log.debug("Proxy already in {}", proxies);
            }
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

    /*
    @Override
    public String toString() {
        return "ProxyQueue [proxySet=" + proxySet + ", proxies=" + proxies
                + ", pausedProxies=" + pausedProxies + "]";
    }
    */
}
