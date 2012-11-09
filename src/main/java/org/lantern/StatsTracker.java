package org.lantern;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

import org.jboss.netty.channel.Channel;
import org.json.simple.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.maxmind.geoip.LookupService;

/**
 * Class for tracking statistics about Lantern.
 */
public class StatsTracker implements Stats {
    
    private final static Logger log = 
        LoggerFactory.getLogger(StatsTracker.class);

    private final AtomicLong bytesProxied = new AtomicLong(0L);
    
    private final AtomicLong directBytes = new AtomicLong(0L);
    
    private final AtomicInteger proxiedRequests = new AtomicInteger(0);
    
    private final AtomicInteger directRequests = new AtomicInteger(0);

    private static final ConcurrentHashMap<String, CountryData> countries = 
        new ConcurrentHashMap<String, CountryData>();
    
    /** 
     * getXYZBytesPerSecond calls will be calculated using a moving 
     * window average of size DATA_RATE_SECONDS.
     */ 
    public static final int DATA_RATE_SECONDS = 1;
    private static final long ONE_SECOND = 1000;
    private static final long ONE_MINUTE = 60*ONE_SECOND;
    private static final long ONE_HOUR = 60*ONE_MINUTE;
    private static final long ONE_DAY = 24*ONE_HOUR;

    /** 
     * 1-second time-buckets for i/o bytes - DATA_RATE_SECONDS+1 seconds 
     * prior only looking to track average up/down rates for the moment
     * could be adjusted to track more etc.
     */
    private static final TimeSeries1D upBytesPerSecondViaProxies
        = new TimeSeries1D(ONE_SECOND, ONE_SECOND*(DATA_RATE_SECONDS+1));
    private static final TimeSeries1D downBytesPerSecondViaProxies
        = new TimeSeries1D(ONE_SECOND, ONE_SECOND*(DATA_RATE_SECONDS+1));
    private static final TimeSeries1D upBytesPerSecondForPeers
        = new TimeSeries1D(ONE_SECOND, ONE_SECOND*(DATA_RATE_SECONDS+1));
    private static final TimeSeries1D downBytesPerSecondForPeers
        = new TimeSeries1D(ONE_SECOND, ONE_SECOND*(DATA_RATE_SECONDS+1));
    private static final TimeSeries1D upBytesPerSecondToPeers
        = new TimeSeries1D(ONE_SECOND, ONE_SECOND*(DATA_RATE_SECONDS+1));
    private static final TimeSeries1D downBytesPerSecondFromPeers
        = new TimeSeries1D(ONE_SECOND, ONE_SECOND*(DATA_RATE_SECONDS+1));
    
    
    /**
     * Peer count tracking, just tracks current for now. 
     */
    private static final PeerCounter peersPerSecond = 
        new PeerCounter(ONE_SECOND, ONE_SECOND*2);
    
    
    private boolean upnp;
    
    private boolean natpmp;
    
    @Override
    public long getUptime() {
        return System.currentTimeMillis() - LanternConstants.START_TIME;
    }
    
    /**
     * Resets all stats that the server treats as cumulative aggregates -- i.e.
     * where the server doesn't differentiate data for individual users and
     * simply adds whatever we send them to the total.
     */
    public void resetCumulativeStats() {
        this.directRequests.set(0);
        this.directBytes.set(0L);
        this.proxiedRequests.set(0);
        this.bytesProxied.set(0L);
    }
    
    public void resetUserStats() {
        upBytesPerSecondViaProxies.reset();
        downBytesPerSecondViaProxies.reset();
        upBytesPerSecondForPeers.reset();
        downBytesPerSecondForPeers.reset();
        upBytesPerSecondToPeers.reset();
        downBytesPerSecondFromPeers.reset();
        peersPerSecond.reset();
        // others?
    }
    
    @Override
    public long getPeerCount() {
        return peersPerSecond.latestValue();
    }
    
    @Override
    public long getPeerCountThisRun() {
        return peersPerSecond.lifetimeTotal();
    }
    
    @Override
    public long getUpBytesThisRun() {
        return getUpBytesThisRunForPeers() + // requests uploaded to internet for peers
               getUpBytesThisRunViaProxies() + // requests sent to other proxies
               getUpBytesThisRunToPeers();   // responses to requests we proxied
    }
    
    @Override
    public long getDownBytesThisRun() {
        return getDownBytesThisRunForPeers() + // downloaded from internet for peers
               getDownBytesThisRunViaProxies() + // replys to requests proxied by others
               getDownBytesThisRunFromPeers(); // requests from peers        
    }
    
    @Override
    public long getUpBytesThisRunForPeers() {
        return upBytesPerSecondForPeers.lifetimeTotal();
    }
    
    @Override
    public long getUpBytesThisRunViaProxies() {
        return upBytesPerSecondViaProxies.lifetimeTotal();
    }

    @Override
    public long getUpBytesThisRunToPeers() {
        return upBytesPerSecondToPeers.lifetimeTotal();
    }
    
    @Override
    public long getDownBytesThisRunForPeers() {
        return downBytesPerSecondForPeers.lifetimeTotal();
    }

    @Override
    public long getDownBytesThisRunViaProxies() {
        return downBytesPerSecondViaProxies.lifetimeTotal();
    }

    @Override
    public long getDownBytesThisRunFromPeers() {
        return downBytesPerSecondFromPeers.lifetimeTotal();
    }
    
    @Override
    public long getUpBytesPerSecond() {
        return getUpBytesPerSecondForPeers() + // requests uploaded to internet for peers
               getUpBytesPerSecondViaProxies() + // requests sent to other proxies
               getUpBytesPerSecondToPeers();   // responses to requests we proxied
    }

    @Override
    public long getDownBytesPerSecond() {
        return getDownBytesPerSecondForPeers() + // downloaded from internet for peers
               getDownBytesPerSecondViaProxies() + // replys to requests proxied by others
               getDownBytesPerSecondFromPeers(); // requests from peers
    }
    
    @Override
    public long getUpBytesPerSecondForPeers() {
        return getBytesPerSecond(upBytesPerSecondForPeers);
    }

    @Override
    public long getUpBytesPerSecondViaProxies() {
        return getBytesPerSecond(upBytesPerSecondViaProxies);
    }

    @Override
    public long getDownBytesPerSecondForPeers() {
        return getBytesPerSecond(downBytesPerSecondForPeers);
    }
    
    @Override
    public long getDownBytesPerSecondViaProxies() {
        return getBytesPerSecond(downBytesPerSecondViaProxies);
    }
    
    @Override
    public long getDownBytesPerSecondFromPeers() {
        return getBytesPerSecond(downBytesPerSecondFromPeers);
    }
    
    @Override
    public long getUpBytesPerSecondToPeers() {
        return getBytesPerSecond(upBytesPerSecondToPeers);
    }
    
    public static long getBytesPerSecond(final TimeSeries1D ts) {
        long now = System.currentTimeMillis();
        // prior second to the one we're still accumulating 
        long windowEnd = ((now / ONE_SECOND) * ONE_SECOND) - 1;
        // second DATA_RATE_SECONDS before that
        long windowStart = windowEnd - (ONE_SECOND*DATA_RATE_SECONDS);
        // take the average
        return (long) (ts.windowAverage(windowStart, windowEnd) + 0.5);
    }
    
    /**
     * request bytes this lantern proxy sent to other lanterns for proxying
     */
    public void addUpBytesViaProxies(final long bp) {
        upBytesPerSecondViaProxies.addData(bp);
        log.debug("upBytesPerSecondViaProxies += {} up-rate {}", bp, getUpBytesPerSecond());
    }

    /**
     * response bytes downloaded by Peers for this lantern
     */
    public void addDownBytesViaProxies(final long bp) {
        downBytesPerSecondViaProxies.addData(bp);
        log.debug("downBytesPerSecondViaProxies += {} down-rate {}", bp, getDownBytesPerSecond());
    }

    /**
     * bytes sent upstream on behalf of another lantern by this
     * lantern
     */
    public void addUpBytesForPeers(final long bp) {
        upBytesPerSecondForPeers.addData(bp);
        log.debug("upBytesPerSecondForPeers += {} up-rate {}", bp, getUpBytesPerSecond());
    }
    
    /**
     * bytes downloaded on behalf of another lantern by this lantern
     */
    public void addDownBytesForPeers(final long bp) {
        downBytesPerSecondForPeers.addData(bp);
        log.debug("downBytesPerSecondForPeers += {} down-rate {}", bp, getDownBytesPerSecond());
    }
    
    /**
     * request bytes sent by peers to this lantern
     */
    public void addDownBytesFromPeers(final long bp) {
        downBytesPerSecondFromPeers.addData(bp);
        log.debug("downBytesPerSecondFromPeers += {} down-rate {}", bp, getDownBytesPerSecond());
    }
    
    /** 
     * reply bytes send to peers by this lantern
     */
    public void addUpBytesToPeers(final long bp) {
        upBytesPerSecondToPeers.addData(bp);
        log.debug("upBytesPerSecondToPeers += {} up-rate {}", bp, getUpBytesPerSecond());
    }

    @Override
    public long getTotalBytesProxied() {
        return bytesProxied.get();
    }

    public void addDirectBytes(final int db) {
        directBytes.addAndGet(db);
    }

    @Override
    public long getDirectBytes() {
        return directBytes.get();
    }

    public void incrementDirectRequests() {
        this.directRequests.incrementAndGet();
    }

    public void incrementProxiedRequests() {
        this.proxiedRequests.incrementAndGet();
    }

    @Override
    public int getTotalProxiedRequests() {
        return proxiedRequests.get();
    }

    @Override
    public int getDirectRequests() {
        return directRequests.get();
    }
    

    public void addBytesProxied(final long bp, final Channel channel) {
        bytesProxied.addAndGet(bp);
        final CountryData cd = toCountryData(channel);
        if (cd != null) {
            cd.bytes += bp;
        }
        else {
            log.warn("No CountryData for {} Not adding bytes proxied.", channel);
        }
    }

    public void addBytesProxied(final long bp, final Socket sock) {
        bytesProxied.addAndGet(bp);
        final CountryData cd = toCountryData(sock);
        if (cd != null) {
            cd.bytes += bp;
        }
        else {
            log.warn("No CountryData for {} Not adding bytes proxied.", sock);
        }
    }

    public void setUpnp(final boolean upnp) {
        this.upnp = upnp;
    }

    @Override
    public boolean isUpnp() {
        return upnp;
    }

    public void setNatpmp(final boolean natpmp) {
        this.natpmp = natpmp;
    }

    @Override
    public boolean isNatpmp() {
        return natpmp;
    }

    private CountryData toCountryData(final Channel channel) {
        final InetSocketAddress isa = 
            (InetSocketAddress) channel.getRemoteAddress();
        return toCountryData(isa);
    }
    
    
    private CountryData toCountryData(final Socket sock) {
        final InetSocketAddress isa = 
            (InetSocketAddress)sock.getRemoteSocketAddress();
        return toCountryData(isa);
    }
    
    private CountryData toCountryData(final InetSocketAddress isa) {
        if (isa == null) {
            return null;
        }
        
        final LookupService ls = LanternHub.getGeoIpLookup();
        final InetAddress addr = isa.getAddress();
        final Country country = new Country(ls.getCountry(addr));
        final CountryData cd;
        final CountryData temp = new CountryData(country);
        final CountryData existing = 
            countries.putIfAbsent(country.getCode(), temp);
        if (existing == null) {
            cd = temp;
        } else {
            cd = existing;
        }
        
        cd.addresses.add(addr);
        return cd;
    }
    

    public static CountryData newCountryData(final String cc, 
        final String name) {
        if (countries.containsKey(cc)) {
            return countries.get(cc);
        } 
        final Country co = new Country(cc, name);
        final CountryData cd = new CountryData(co);
        countries.put(cc, cd);
        return cd;
    }

    @Override
    public String getCountryCode() {
        return LanternHub.censored().countryCode();
    }
    
    @Override
    public String getVersion() {
        return LanternConstants.VERSION;
    }
    
    public static final class CountryData {
        private final Set<InetAddress> addresses = new HashSet<InetAddress>();
        private volatile long bytes;
        
        private final JSONObject lanternData = new JSONObject();
        final JSONObject data = new JSONObject();
        
        private CountryData(final Country country) {
            data.put("censored", LanternHub.censored().isCensored(country));
            data.put("name", country.getName());
            data.put("code", country.getCode());
            data.put("lantern", lanternData);
        }
    }
}
