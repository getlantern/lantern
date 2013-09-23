package org.lantern;

import static org.littleshoot.util.FiveTuple.Protocol.*;

import java.net.InetSocketAddress;
import java.net.URI;
import java.util.Date;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

import javax.net.ssl.SSLEngine;

import org.lantern.state.Peer;
import org.lantern.state.Peer.Type;
import org.littleshoot.proxy.ChainedProxy;
import org.littleshoot.proxy.TransportProtocol;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.FiveTuple.Protocol;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class ProxyHolder implements Comparable<ProxyHolder>,
        ChainedProxy {

    private static final Logger LOG = LoggerFactory.getLogger(ProxyHolder.class);
    private final ProxyTracker proxyTracker;

    private final PeerFactory peerFactory;

    private final LanternTrustStore lanternTrustStore;

    private final URI jid;

    private final FiveTuple fiveTuple;

    private final AtomicLong timeOfDeath = new AtomicLong(-1);
    private final AtomicInteger failures = new AtomicInteger();

    private final Type type;

    private volatile Peer peer;

    public ProxyHolder(final ProxyTracker proxyTracker,
            final PeerFactory peerFactory,
            final LanternTrustStore lanternTrustStore, 
            final URI jid, final InetSocketAddress isa,
            final Type type) {
        this(proxyTracker, peerFactory, lanternTrustStore, jid,
                new FiveTuple(null, isa, Protocol.TCP), type);
    }

    public ProxyHolder(final ProxyTracker proxyTracker,
            final PeerFactory peerFactory,
            final LanternTrustStore lanternTrustStore,
            final URI jid, final FiveTuple tuple,
            final Type type) {
        this.proxyTracker = proxyTracker;
        this.peerFactory = peerFactory;
        this.lanternTrustStore = lanternTrustStore;
        this.jid = jid;
        this.fiveTuple = tuple;
        this.type = type;
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
    public String toString() {
        long timeOfDeath = this.timeOfDeath.get();
        String timeOfDeathStr;
        if (timeOfDeath == -1) {
            timeOfDeathStr = " (alive)";
        } else {
            timeOfDeathStr = "@" + new Date(timeOfDeath) + " retry at "
                    + new Date(getRetryTime());
        }
        return "ProxyHolder [isa=" + getFiveTuple() + timeOfDeathStr + "]";
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result
                + ((fiveTuple == null) ? 0 : fiveTuple.hashCode());
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
        return true;
    }

    /**
     * Time that the proxy became unreachable, in millis since epoch, or -1 for
     * never
     * */
    public long getTimeOfDeath() {
        return timeOfDeath.get();
    }

    public void setTimeOfDeath(long timeOfDeath) {
        this.timeOfDeath.set(timeOfDeath);
    }

    public int getFailures() {
        return failures.get();
    }

    public void resetFailures() {
        setTimeOfDeath(-1);
        this.failures.set(0);
    }

    private void incrementFailures() {
        failures.incrementAndGet();
    }

    public void addFailure() {
        if (isConnected()) {
            long now = new Date().getTime();
            setTimeOfDeath(now);
        }
        incrementFailures();
    }

    @Override
    public int compareTo(ProxyHolder o) {
        return (int) (getRetryTime() - o.getRetryTime());
    }

    public long getRetryTime() {
        // exponential backoff - 5,10,20,40, etc seconds
        return timeOfDeath.get() + 1000 * 5
                * (long) (Math.pow(2, failures.get()));
    }

    public URI getJid() {
        return jid;
    }

    public Type getType() {
        return type;
    }

    public boolean isConnected() {
        return timeOfDeath.get() <= 0;
    }

    public String getProxyUsername() {
        // TODO: Implement!
        return "";
    }

    public String getProxyPassword() {
        // TODO: Implement!
        return "";
    }

    /**
     * 
     * @return
     */
    public boolean isNatTraversed() {
        return fiveTuple.getProtocol() == UDP;
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
     * If the protocol is UDP, we use the local address of the {@link FiveTuple}
     * as our local address from which to connect to the chained proxy,
     * otherwise we leave this null to let the connection proceed from whatever
     * available port.
     */
    @Override
    public InetSocketAddress getLocalAddress() {
        return UDP == fiveTuple.getProtocol() ? fiveTuple.getLocal() : null;
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
        resetFailures();
        Peer peer = getPeer();
        if (peer != null) {
            peer.connected();
        }
    }

    @Override
    public void connectionFailed(Throwable cause) {
        // TODO: For some reason the stack trace we get here just includes
        // the message -- we really need the full stack along with causes.
        LOG.info("Could not connect to proxy at ip: "+
                this.fiveTuple.getRemote(), cause);
        proxyTracker.onCouldNotConnect(this);
    }

    @Override
    public void disconnected() {
        Peer peer = getPeer();
        if (peer != null) {
            peer.disconnected();
        }
    }
}