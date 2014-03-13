package org.lantern.state;

import java.net.InetAddress;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;

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
    private Counter requestsGiven = Counter.averageOverOneSecond();
    private Counter bytesGiven = Counter.averageOverOneSecond();
    private Counter requestsGotten = Counter.averageOverOneSecond();
    private Counter bytesGotten = Counter.averageOverOneSecond();
    private Counter directBytes = Counter.averageOverOneSecond();

    private AtomicBoolean usingUPnP = new AtomicBoolean(false);
    private AtomicBoolean usingNATPMP = new AtomicBoolean(false);

    private final Set<InetAddress> distinctProxiedClientAddresses = new HashSet<InetAddress>();

    private final Map<String, Long> bytesGivenPerCountry = new HashMap<String, Long>();

    @JsonView({ Run.class, Persistent.class })
    public Counter getRequestsGiven() {
        return requestsGiven;
    }

    public void setRequestsGiven(Counter requestsGiven) {
        this.requestsGiven = requestsGiven;
    }

    public void addRequestGiven() {
        requestsGiven.add(1);
    }

    @JsonView({ Run.class, Persistent.class })
    public Counter getBytesGiven() {
        return bytesGiven;
    }

    public void setBytesGiven(Counter bytesGiven) {
        this.bytesGiven = bytesGiven;
    }

    public void addBytesGiven(long bytes) {
        bytesGiven.add(bytes);
    }

    synchronized public void addBytesGivenForLocation(GeoData geoData,
            long bytes) {
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
    public Counter getRequestsGotten() {
        return requestsGotten;
    }

    public void setRequestsGotten(Counter requestsGotten) {
        this.requestsGotten = requestsGotten;
    }

    public void incrementRequestGotten() {
        requestsGotten.add(1);
    }

    @JsonView({ Run.class, Persistent.class })
    public Counter getBytesGotten() {
        return bytesGotten;
    }

    public void setBytesGotten(Counter bytesGotten) {
        this.bytesGotten = bytesGotten;
    }

    public void addBytesGotten(long bytes) {
        bytesGotten.add(bytes);
    }

    @JsonView({ Run.class, Persistent.class })
    public Counter getDirectBytes() {
        return directBytes;
    }

    public void setDirectBytes(Counter directBytes) {
        this.directBytes = directBytes;
    }

    public void addDirectBytes(long bytes) {
        directBytes.add(bytes);
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

    synchronized public void addProxiedClientAddress(InetAddress address) {
        distinctProxiedClientAddresses.add(address);
    }

    @JsonView({ Run.class })
    public long getDistinctPeers() {
        return distinctProxiedClientAddresses.size();
    }

    public Stats toStats() {
        Stats stats = new Stats();

        stats.setCounter("requestsGiven", requestsGiven.captureDelta());
        stats.setCounter("bytesGiven", bytesGiven.captureDelta());
        stats.setCounter("requestsGotten", requestsGotten.captureDelta());
        stats.setCounter("bytesGotten", bytesGotten.captureDelta());
        stats.setCounter("directBytes", directBytes.captureDelta());

        for (Map.Entry<String, Long> entry : bytesGivenPerCountry.entrySet()) {
            stats.setCounter("bytesGiven_" + entry.getKey().toLowerCase(),
                    entry.getValue());
        }

        stats.setGauge("usingUPnP", usingUPnP.get() ? 1 : 0);
        stats.setGauge("usingNATPMP", usingNATPMP.get() ? 1 : 0);

        stats.setGauge("bpsGiven", bytesGiven.getRate());
        stats.setGauge("bpsGotten", bytesGotten.getRate());

        stats.setGauge("distinctPeers", getDistinctPeers());

        return stats;
    }

    public Stats userStats(Stats instanceStats) {
        Stats stats = new Stats();
        stats.setCounter(instanceStats.getCounter());

        // We always report that we're online, because if we can report it,
        // we must be online!
        stats.setGauge("online", 1);

        return stats;
    }

}
