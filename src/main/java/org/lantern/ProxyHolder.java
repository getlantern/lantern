package org.lantern;

import static org.littleshoot.util.FiveTuple.Protocol.*;

import java.net.ConnectException;
import java.net.InetSocketAddress;
import java.net.URI;
import java.util.Date;
import java.util.concurrent.atomic.AtomicLong;

import javax.net.ssl.SSLEngine;

import org.lantern.proxy.BaseChainedProxy;
import org.lantern.state.Peer;
import org.lantern.state.Peer.Type;
import org.littleshoot.proxy.TransportProtocol;
import org.littleshoot.util.FiveTuple;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class ProxyHolder extends BaseChainedProxy
        implements Comparable<ProxyHolder> {

    private static final Logger LOG = LoggerFactory
            .getLogger(ProxyHolder.class);

    private final ProxyTracker proxyTracker;

    private final PeerFactory peerFactory;

    private final LanternTrustStore lanternTrustStore;

    private final URI jid;

    private final FiveTuple fiveTuple;

    private final boolean natTraversed;

    /**
     * <p>
     * Once connecting to this proxy fails, this tracks the first time that
     * connecting started failing. Once a connection is successful, this is set
     * to 0.
     * </p>
     * 
     * <p>
     * We start this at 1 on the assumption that the proxy is disconnected until
     * proven otherwise.
     * </p>
     */
    private final AtomicLong timeOfOldestConsecFailure = new AtomicLong(1);

    /**
     * Tracks the time of the most recent failure since connecting to this proxy
     * started failing.
     */
    private final AtomicLong timeOfNewestConsecFailure = new AtomicLong(0);

    private final Type type;

    private volatile Peer peer;

    public ProxyHolder(final ProxyTracker proxyTracker,
            final PeerFactory peerFactory,
            final LanternTrustStore lanternTrustStore,
            final URI jid, final FiveTuple tuple,
            final Type type, final boolean natTraversed,
            final String lanternAuthToken) {
        super(lanternAuthToken);
        this.proxyTracker = proxyTracker;
        this.peerFactory = peerFactory;
        this.lanternTrustStore = lanternTrustStore;
        this.jid = jid;
        this.fiveTuple = tuple;
        this.type = type;
        this.natTraversed = natTraversed;
    }

    public FiveTuple getFiveTuple() {
        return fiveTuple;
    }

    /**
     * Get the {@link Peer} for this ProxyHolder, lazily looking it up from our
     * {@link PeerFactory}.
     * 
     * @return
     */
    public Peer getPeer() {
        if (peer == null) {
            peer = peerFactory.peerForJid(jid);
        }
        return peer;
    }

    @Override
    synchronized public String toString() {
        Date oldestConsecFailure = null;
        Date newestConsecFailure = null;
        Date retryTime = null;
        if (timeOfNewestConsecFailure.get() > 0) {
            oldestConsecFailure = new Date(timeOfOldestConsecFailure.get());
            newestConsecFailure = new Date(timeOfNewestConsecFailure.get());
            retryTime = new Date(getRetryTime());
        }
        return "ProxyHolder [jid=" + jid + ", fiveTuple=" + fiveTuple
                + ", timeOfOldestConsecFailure=" + oldestConsecFailure
                + ", timeOfNewestConsecFailure=" + newestConsecFailure
                + ", retryTime=" + retryTime
                + ", type=" + type + "] connected? " + isConnected();
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result
                + ((fiveTuple == null) ? 0 : fiveTuple.hashCode());
        result = prime * result + ((jid == null) ? 0 : jid.hashCode());
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
        if (fiveTuple == null) {
            if (other.fiveTuple != null)
                return false;
        } else if (!fiveTuple.equals(other.fiveTuple))
            return false;
        if (jid == null) {
            if (other.jid != null)
                return false;
        } else if (!jid.equals(other.jid))
            return false;
        return true;
    }

    synchronized private void failuresStarted() {
        long now = System.currentTimeMillis();
        timeOfOldestConsecFailure.set(now);
        timeOfNewestConsecFailure.set(now);
    }

    private void failuresContinued() {
        timeOfNewestConsecFailure.set(System.currentTimeMillis());
    }

    synchronized public void markConnected() {
        timeOfOldestConsecFailure.set(0l);
        timeOfNewestConsecFailure.set(0l);
    }

    synchronized public void resetRetryInterval() {
        timeOfNewestConsecFailure.set(timeOfOldestConsecFailure.get());
    }

    /**
     * If this is a new proxy and our first attempt to connect fails, it is
     * permitted to try falling back to connecting to the same peer via a NAT
     * traversal.
     * 
     * @return
     */
    public boolean attemptNatTraversalIfConnectionFailed() {
        return !isNatTraversed() &&
                timeOfOldestConsecFailure.get() == 1l &&
                timeOfNewestConsecFailure.get() == 1l;
    }

    synchronized public void failedToConnect() {
        if (isConnected()) {
            LOG.debug("Setting proxy as disconnected: {}", fiveTuple);
            failuresStarted();
        } else {
            failuresContinued();
        }
    }

    @Override
    public int compareTo(ProxyHolder o) {
        return (int) (getRetryTime() - o.getRetryTime());
    }

    synchronized public long getRetryTime() {
        long timeDead = timeOfNewestConsecFailure.get()
                - timeOfOldestConsecFailure.get();
        if (timeDead <= 0) {
            // First time retrying, 100 milliseconds
            return timeOfNewestConsecFailure.get() + 5000;
        } else {
            // Back off exponentially up to a maximum of 5 seconds and at least
            // 100 milliseconds
            long waitTime = Math.max(timeDead, 100);
            waitTime = Math.min(waitTime, 5000);
            return timeOfNewestConsecFailure.get() + waitTime;
        }
    }

    public URI getJid() {
        return jid;
    }

    public Type getType() {
        return type;
    }

    public boolean isConnected() {
        return timeOfOldestConsecFailure.get() <= 0;
    }

    public boolean needsConnectionTest() {
        return timeOfOldestConsecFailure.get() > 0 &&
                timeOfNewestConsecFailure.get() > 0;
    }

    /**
     * 
     * @return
     */
    public boolean isNatTraversed() {
        return natTraversed;
    }

    /***************************************************************************
     * Implementation of the ChainedProxy interface
     **************************************************************************/

    /**
     * We use the remote address of the {@link FiveTuple} as our chained proxy
     * address.
     */
    @Override
    public InetSocketAddress getChainedProxyAddress() {
        return fiveTuple.getRemote();
    }

    /**
     * If the we are nat traversed, we use the local address of the
     * {@link FiveTuple} as our local address from which to connect to the
     * chained proxy, otherwise we leave this null to let the connection proceed
     * from whatever available port.
     */
    @Override
    public InetSocketAddress getLocalAddress() {
        return natTraversed ? fiveTuple.getLocal() : null;
    }

    /**
     * For UDP connections, we tell the proxy to use
     * {@link TransportProtocol#UDT}, otherwise we tell it to use
     * {@link TransportProtocol#TCP}.
     */
    @Override
    public TransportProtocol getTransportProtocol() {
        return UDP == fiveTuple.getProtocol() ? TransportProtocol.UDT
                : TransportProtocol.TCP;
    }

    /**
     * All our connections to chained proxies require encryption.
     */
    @Override
    public boolean requiresEncryption() {
        return true;
    }

    @Override
    public SSLEngine newSslEngine() {
        return lanternTrustStore.newSSLEngine();
    }

    @Override
    public void connectionSucceeded() {
        markConnected();
        Peer peer = getPeer();
        if (peer != null) {
            peer.connected();
        }
    }

    @Override
    public void connectionFailed(Throwable cause) {
        String message = cause != null ? cause.getMessage() : null;
        LOG.debug("Got connectionFailed from LittleProxy: {}", message);
        if (cause instanceof ConnectException) {
            LOG.info("Could not connect to proxy at ip: " +
                    this.fiveTuple.getRemote(), cause);
            proxyTracker.onCouldNotConnect(this);
        } else {
            LOG.debug("Ignoring non-ConnectException");
        }
    }

    @Override
    public void disconnected() {
        Peer peer = getPeer();
        if (peer != null) {
            peer.disconnected();
        }
    }
}