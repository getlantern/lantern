package org.lantern.state;

import java.net.InetAddress;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.GeoData;
import org.lantern.monitoring.Counter;
import org.lantern.monitoring.Stats;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;

/**
 * Tracks statistics for this instance of Lantern.
 */
public class InstanceStats {
    private AtomicLong requestsGiven = new AtomicLong(0l);
    private AtomicLong bytesGiven = new AtomicLong(0l);
    private AtomicLong requestsGotten = new AtomicLong(0l);
    private AtomicLong bytesGotten = new AtomicLong(0l);
    private AtomicLong directBytes = new AtomicLong(0l);

    private AtomicBoolean online = new AtomicBoolean(false);
    private AtomicBoolean usingUPnP = new AtomicBoolean(false);
    private AtomicBoolean usingNATPMP = new AtomicBoolean(false);

    private final Counter bpsGiven = Counter.averageOverOneSecond();
    private final Counter bpsGotten = Counter.averageOverOneSecond();

    private final Set<InetAddress> distinctProxiedClientAddresses = new HashSet<InetAddress>();
    
    private final Map<String, Long> bytesGivenPerCountry = new HashMap<String, Long>();
    
    @JsonView({ Run.class, Persistent.class })
    public long getRequestsGiven() {
        return requestsGiven.get();
    }

    public void setRequestsGiven(long value) {
        requestsGiven.set(value);
    }

    public void addRequestGiven() {
        requestsGiven.incrementAndGet();
    }

    @JsonView({ Run.class, Persistent.class })
    public long getBytesGiven() {
        return bytesGiven.get();
    }

    public void setBytesGiven(long value) {
        bytesGiven.set(value);
    }

    public void addBytesGiven(long bytes) {
        bytesGiven.addAndGet(bytes);
        bpsGiven.add(bytes);
    }
    
    synchronized public void addBytesGivenForLocation(GeoData geoData, long bytes) {
        if (geoData != null) {
            String countryCode = geoData.getCountrycode();
            Long originalBytes = bytesGivenPerCountry.get(countryCode);
            if (originalBytes == null) {
                originalBytes = 0l;
            }
            bytesGivenPerCountry.put(countryCode, originalBytes + bytes);
        }
    }

    @JsonView({ Run.class, Persistent.class })
    public long getRequestsGotten() {
        return requestsGotten.get();
    }

    public void setRequestsGotten(long value) {
        requestsGotten.set(value);
    }

    public void incrementRequestGotten() {
        requestsGotten.incrementAndGet();
    }

    @JsonView({ Run.class, Persistent.class })
    public long getBytesGotten() {
        return bytesGotten.get();
    }

    public void setBytesGotten(long value) {
        bytesGotten.set(value);
    }

    public void addBytesGotten(long bytes) {
        bytesGotten.addAndGet(bytes);
        bpsGotten.add(bytes);
    }

    @JsonView({ Run.class, Persistent.class })
    public long getDirectBytes() {
        return directBytes.get();
    }

    public void setDirectBytes(long value) {
        requestsGiven.set(value);
    }

    public void addDirectBytes(long bytes) {
        directBytes.addAndGet(bytes);
    }

    @JsonView({ Run.class })
    public boolean getOnline() {
        return online.get();
    }

    public void setOnline(boolean online) {
        this.online.set(online);
    }

    @JsonView({ Run.class })
    public boolean getUsingUPnP() {
        return usingUPnP.get();
    }

    public void setUsingUPnP(boolean usingUPnP) {
        this.usingUPnP.set(usingUPnP);
    }

    @JsonView({ Run.class })
    public boolean getUsingNATPMP() {
        return usingNATPMP.get();
    }

    public void setUsingNATPMP(boolean usingNATPMP) {
        this.usingNATPMP.set(usingNATPMP);
    }

    @JsonView({ Run.class })
    public long getBpsGiven() {
        return bpsGiven.getRate();
    }

    @JsonView({ Run.class })
    public long getBpsGotten() {
        return bpsGotten.getRate();
    }
    
    synchronized public void addProxiedClientAddress(InetAddress address) {
        distinctProxiedClientAddresses.add(address);
    }
    
    @JsonView({ Run.class })
    public long getDistinctPeers() {
        return distinctProxiedClientAddresses.size();
    }

    public Stats toStats() {
        Stats stats = new Stats();

        stats.setCounter("requestsGiven", requestsGiven.get());
        stats.setCounter("bytesGiven", bytesGiven.get());
        stats.setCounter("requestsGotten", requestsGotten.get());
        stats.setCounter("bytesGotten", bytesGotten.get());
        stats.setCounter("directBytes", directBytes.get());
        
        for (Map.Entry<String, Long> entry : bytesGivenPerCountry.entrySet()) {
            stats.setCounter("bytesGiven_" + entry.getKey().toLowerCase(), entry.getValue());
        }

        stats.setGauge("online", online.get() ? 1 : 0);
        stats.setGauge("usingUPnP", usingUPnP.get() ? 1 : 0);
        stats.setGauge("usingNATPMP", usingNATPMP.get() ? 1 : 0);

        stats.setGauge("bpsGiven", bpsGiven.getRate());
        stats.setGauge("bpsGotten", bpsGotten.getRate());
        
        stats.setGauge("distinctPeers", getDistinctPeers());

        return stats;
    }

}
