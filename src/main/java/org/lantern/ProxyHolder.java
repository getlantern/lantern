package org.lantern;

import java.net.InetSocketAddress;
import java.net.URI;
import java.util.Date;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import org.lantern.state.Peer.Type;
import org.lantern.util.LanternTrafficCounter;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.FiveTuple.Protocol;

public final class ProxyHolder implements Comparable<ProxyHolder> {

    private final String id;

    private final URI jid;

    private final FiveTuple fiveTuple;
    private final LanternTrafficCounter trafficShapingHandler;

    private long timeOfDeath = -1;
    private final AtomicInteger failures = new AtomicInteger();

    private final Type type;
    
    private final AtomicBoolean lastFailed = new AtomicBoolean(true);

    public ProxyHolder(final String id, final URI jid,
            final InetSocketAddress isa,
            final LanternTrafficCounter trafficShapingHandler,
            final Type type) {
        this.id = id;
        this.jid = jid;
        this.fiveTuple = new FiveTuple(null, isa, Protocol.TCP);
        this.trafficShapingHandler = trafficShapingHandler;
        this.type = type;
    }

    public ProxyHolder(final String id, final URI jid,
            final FiveTuple tuple,
            final LanternTrafficCounter trafficShapingHandler,
            final Type type) {
        this.id = id;
        this.jid = jid;
        this.fiveTuple = tuple;
        this.trafficShapingHandler = trafficShapingHandler;
        this.type = type;
    }

    public String getId() {
        return id;
    }

    public FiveTuple getFiveTuple() {
        return fiveTuple;
    }

    public LanternTrafficCounter getTrafficShapingHandler() {
        return trafficShapingHandler;
    }


    @Override
    public String toString() {
        String timeOfDeathStr;
        if (timeOfDeath == -1) {
            timeOfDeathStr = " (alive)";
        } else {
            timeOfDeathStr = "@" + new Date(timeOfDeath) + " retry at " + new Date(getRetryTime());
        }
        return "ProxyHolder [isa=" + getFiveTuple() + timeOfDeathStr  + "]";
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result + ((id == null) ? 0 : id.hashCode());
        result = prime * result + ((fiveTuple == null) ? 0 : fiveTuple.hashCode());
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
        if (fiveTuple == null) {
            if (other.fiveTuple != null)
                return false;
        } else if (!fiveTuple.equals(other.fiveTuple))
            return false;
        return true;
    }

    /** Time that the proxy became unreachable, in millis since epoch, or -1
     * for never
     * */
    public long getTimeOfDeath() {
        return timeOfDeath;
    }

    public void setTimeOfDeath(long timeOfDeath) {
        this.timeOfDeath = timeOfDeath;
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
        this.lastFailed.set(true);
        if (failures.get() == 0) {
            long now = new Date().getTime();
            setTimeOfDeath(now);
        }
        incrementFailures();

    }

    @Override
    public int compareTo(ProxyHolder o) {
        return (int)(getRetryTime() - o.getRetryTime());
    }

    public long getRetryTime() {
        //exponential backoff - 5,10,20,40, etc seconds
        return timeOfDeath + 1000 * 5 * (long)(Math.pow(2, failures.get()));
    }

    public URI getJid() {
        return jid;
    }

    public Type getType() {
        return type;
    }

    public boolean isConnected() {
        return timeOfDeath <= 0;
    }
    
    public void addSuccess() {
        lastFailed.set(false);
    }
    
    /**
     * Returns whether the last attempt failed or succeeded.
     * 
     * @return <code>true</code> if the last connection attempt failed, 
     * otherwise <code>false</code>.
     */
    public boolean lastFailed() {
        return lastFailed.get();
    }

    public String getProxyUsername() {
        // TODO: Implement!
        return "";
    }

    public String getProxyPassword() {
        // TODO: Implement!
        return "";
    }
}