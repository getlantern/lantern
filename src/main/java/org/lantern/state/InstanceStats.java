package org.lantern.state;

import java.net.InetAddress;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;

import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.geoip.GeoData;
import org.lantern.LanternUtils;
import org.lantern.monitoring.Counter;
import org.lantern.monitoring.Stats;
import org.lantern.monitoring.Stats.Counters;
import org.lantern.monitoring.Stats.Gauges;
import org.lantern.monitoring.Stats.Members;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;

/**
 * Tracks statistics for this instance of Lantern.
 */
public class InstanceStats {
    private Counter allBytes = Counter.averageOverOneSecond();
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
    public Counter getAllBytes() {
        return allBytes;
    }

    public void setAllBytes(Counter allBytes) {
        this.allBytes = allBytes;
    }

    public void addAllBytes(long bytes) {
        allBytes.add(bytes);
    }

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

    public void addBytesGivenForLocation(GeoData geoData,
            long bytes) {
        bytesGiven.add(bytes);
        if (geoData != null) {
            String countryCode = geoData.getCountry().getIsoCode();
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

    public Stats toInstanceStats() {
        Stats stats = new Stats();

        long requestsGiven = this.requestsGiven.captureDelta();
        long bytesGiven = this.bytesGiven.captureDelta();

        stats.setIncrement(Counters.requestsGiven, requestsGiven);
        stats.setIncrement(Counters.bytesGiven, bytesGiven);
        if (LanternUtils.isFallbackProxy()) {
            stats.setIncrement(Counters.requestsGivenByFallback,
                    requestsGiven);
            stats.setIncrement(Counters.bytesGivenByFallback, bytesGiven);
        } else {
            stats.setIncrement(Counters.requestsGivenByPeer, requestsGiven);
            stats.setIncrement(Counters.bytesGivenByPeer, bytesGiven);
        }
        stats.setIncrement(Counters.requestsGotten,
                requestsGotten.captureDelta());
        stats.setIncrement(Counters.bytesGotten, bytesGotten.captureDelta());
        stats.setIncrement(Counters.directBytes, directBytes.captureDelta());

        synchronized(this) {
            for (Map.Entry<String, Long> entry : bytesGivenPerCountry
                    .entrySet()) {
                String country = entry.getKey().toLowerCase();
                Long bytes = entry.getValue();
                stats.setIncrement(Counters.bytesGiven, 
                        country, 
                        bytes);
                if (LanternUtils.isFallbackProxy()) {
                    stats.setIncrement(Counters.bytesGivenByFallback,
                            country,
                            bytes);
                }
            }
            // Clear bytesGivenPerCountry to reset counters
            bytesGivenPerCountry.clear();
        }

        stats.setGauge(Gauges.usingUPnP, usingUPnP.get() ? 1 : 0);
        stats.setGauge(Gauges.usingNATPMP, usingNATPMP.get() ? 1 : 0);

        stats.setGauge(Gauges.bpsGiven, this.bytesGiven.getRate());
        if (LanternUtils.isFallbackProxy()) {
            stats.setGauge(Gauges.bpsGivenByFallback,
                    this.bytesGiven.getRate());
        } else {
            stats.setGauge(Gauges.bpsGivenByPeer, this.bytesGiven.getRate());
        }
        stats.setGauge(Gauges.bpsGotten, bytesGotten.getRate());

        stats.setGauge(Gauges.distinctPeers, getDistinctPeers());

        return stats;
    }

    public Stats toUserStats(
            String userGuid,
            boolean giving,
            boolean getting) {
        Stats stats = new Stats();
        stats.setGauge(Gauges.userOnline, 1);
        if (giving) {
            stats.setGauge(Gauges.userOnlineGiving, 1);
        }
        if (getting) {
            stats.setGauge(Gauges.userOnlineGetting, 1);
        }
        stats.setMember(Members.userOnlineEver, userGuid);
        return stats;
    }

}
