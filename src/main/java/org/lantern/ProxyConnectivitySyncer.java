package org.lantern;

import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

import org.lantern.event.Events;
import org.lantern.event.ProxyConnectionEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ProxyConnectivitySyncer {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Lock connectivityLock = new ReentrantLock();
    
    private final ProxyQueue proxyQueue;
    private final ProxyQueue laeProxyQueue;
    private final ProxyQueue peerProxyQueue;

    public ProxyConnectivitySyncer(final ProxyQueue proxyQueue,
            ProxyQueue laeProxyQueue, ProxyQueue peerProxyQueue) {
        this.proxyQueue = proxyQueue;
        this.laeProxyQueue = laeProxyQueue;
        this.peerProxyQueue = peerProxyQueue;
    }
    
    /**
     * Broadcasts a disconnected event if we just got disconnected from the
     * only proxy we knew about.
     */
    public void syncConnectivity() {
        /*
        try {
            connectivityLock.lockInterruptibly();
            final ConnectivityStatus status;
            if (this.proxyQueue.isEmpty() && this.peerProxyQueue.isEmpty() && 
                this.laeProxyQueue.isEmpty()) {
                status = ConnectivityStatus.DISCONNECTED;
            } else {
                status = ConnectivityStatus.CONNECTED;
            }
            Events.inOderAsyncEventBus().post(new ProxyConnectionEvent(status));
        } catch (final InterruptedException e) {
            log.warn("Interrupted checking for disconnection?", e);
        }
        */
    }
}
