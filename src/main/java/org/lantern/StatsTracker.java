package org.lantern;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

import org.json.simple.JSONObject;
import org.lantern.annotation.Keep;
import org.lantern.event.Events;
import org.lantern.event.ResetEvent;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.state.LocationChangedEvent;
import org.lantern.util.Counter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class for tracking statistics about Lantern.
 */
@Keep
@Singleton
public class StatsTracker implements ClientStats {
    private final static Logger log =
        LoggerFactory.getLogger(StatsTracker.class);

    private final AtomicLong totalBytesProxied = new AtomicLong(0L);
    private final AtomicLong directBytes = new AtomicLong(0L);
    private final AtomicInteger proxiedRequests = new AtomicInteger(0);
    private final AtomicInteger directRequests = new AtomicInteger(0);
    private final AtomicLong bytesProxiedForIran = new AtomicLong(0);
    private final AtomicLong globalBytesProxiedForIran = new AtomicLong(0);
    private final AtomicLong bytesProxiedForChina = new AtomicLong(0);
    private final AtomicLong globalBytesProxiedForChina = new AtomicLong(0);

    private static final ConcurrentHashMap<String, CountryData> countries = 
        new ConcurrentHashMap<String, CountryData>();
    
    /** 
     * 1-second time-buckets for i/o bytes - DATA_RATE_SECONDS+1 seconds 
     * prior only looking to track average up/down rates for the moment
     * could be adjusted to track more etc.
     */
    private static volatile Counter upBytesPerSecondViaProxies = Counter
            .averageOverOneSecond();
    private static volatile Counter downBytesPerSecondViaProxies = Counter
            .averageOverOneSecond();
    private static volatile Counter upBytesPerSecondForPeers = Counter
            .averageOverOneSecond();
    private static volatile Counter downBytesPerSecondForPeers = Counter
            .averageOverOneSecond();
    private static volatile Counter upBytesPerSecondToPeers = Counter
            .averageOverOneSecond();
    private static volatile Counter downBytesPerSecondFromPeers = Counter
            .averageOverOneSecond();
    
    private boolean upnp;
    
    private boolean natpmp;

    private final GeoIpLookupService lookupService;

    private final CountryService countryService;

    private String countryCode;
    
    private final Set<InetAddress> distinctProxiedClientAddresses = new HashSet<InetAddress>();

    @Inject
    public StatsTracker(final GeoIpLookupService lookupService,
        final CountryService countryService) {
        this.lookupService = lookupService;
        this.countryService = countryService;
        Events.register(this);
    }
    
    @Override
    public long getUptime() {
        return System.currentTimeMillis() - LanternClientConstants.START_TIME;
    }
    
    /**
     * Resets all stats that the server treats as cumulative aggregates -- i.e.
     * where the server doesn't differentiate data for individual users and
     * simply adds whatever we send them to the total.
     */
    @Override
    public void resetCumulativeStats() {
        this.directRequests.set(0);
        this.directBytes.set(0L);
        this.proxiedRequests.set(0);
        this.totalBytesProxied.set(0L);
    }
    
    public void resetUserStats() {
        upBytesPerSecondViaProxies  = Counter.averageOverOneSecond();
        downBytesPerSecondViaProxies = Counter.averageOverOneSecond();
        upBytesPerSecondForPeers = Counter.averageOverOneSecond();
        downBytesPerSecondForPeers = Counter.averageOverOneSecond();
        upBytesPerSecondToPeers = Counter.averageOverOneSecond();
        downBytesPerSecondFromPeers = Counter.averageOverOneSecond();
        //peersPerSecond.reset();
        // others?
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
        return upBytesPerSecondForPeers.getTotal();
    }
    
    @Override
    public long getUpBytesThisRunViaProxies() {
        return upBytesPerSecondViaProxies.getTotal();
    }

    @Override
    public long getUpBytesThisRunToPeers() {
        return upBytesPerSecondToPeers.getTotal();
    }
    
    @Override
    public long getDownBytesThisRunForPeers() {
        return downBytesPerSecondForPeers.getTotal();
    }

    @Override
    public long getDownBytesThisRunViaProxies() {
        return downBytesPerSecondViaProxies.getTotal();
    }

    @Override
    public long getDownBytesThisRunFromPeers() {
        return downBytesPerSecondFromPeers.getTotal();
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
    
    public static long getBytesPerSecond(final Counter counter) {
        return counter.getRate();
    }
    
    @Override
    public void addUpBytesViaProxies(final long bp) {
        upBytesPerSecondViaProxies.add(bp);
        log.debug("upBytesPerSecondViaProxies += {} up-rate {}", bp, getUpBytesPerSecond());
    }

    @Override
    public void addDownBytesViaProxies(final long bp) {
        downBytesPerSecondViaProxies.add(bp);
        log.debug("downBytesPerSecondViaProxies += {} down-rate {}", bp, getDownBytesPerSecond());
    }

    @Override
    public void addUpBytesForPeers(final long bp) {
        upBytesPerSecondForPeers.add(bp);
        log.debug("upBytesPerSecondForPeers += {} up-rate {}", bp, getUpBytesPerSecond());
    }
    
    @Override
    public void addDownBytesForPeers(final long bp) {
        downBytesPerSecondForPeers.add(bp);
        log.debug("downBytesPerSecondForPeers += {} down-rate {}", bp, getDownBytesPerSecond());
    }
    
    @Override
    public void addDownBytesFromPeers(final long bp, InetAddress peerAddress) {
        downBytesPerSecondFromPeers.add(bp);
        addBytesProxiedForCountry(bp, peerAddress);
        log.debug("downBytesPerSecondFromPeers += {} down-rate {}", bp, getDownBytesPerSecond());
    }
    
    @Override
    public void addUpBytesToPeers(final long bp, InetAddress peerAddress) {
        upBytesPerSecondToPeers.add(bp);
        addBytesProxiedForCountry(bp, peerAddress);
        log.debug("upBytesPerSecondToPeers += {} up-rate {}", bp, getUpBytesPerSecond());
    }

    @Override
    public long getTotalBytesProxied() {
        return totalBytesProxied.get();
    }

    @Override
    public void addDirectBytes(final long db) {
        directBytes.addAndGet(db);
    }

    @Override
    public long getDirectBytes() {
        return directBytes.get();
    }

    public void incrementDirectRequests() {
        this.directRequests.incrementAndGet();
    }

    @Override
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
    

    @Override
    public void addBytesProxied(final long bp, final InetSocketAddress address) {
        totalBytesProxied.addAndGet(bp);
        if (LanternUtils.isLocalHost(address)) {
            return;
        }
        final CountryData cd = toCountryData(address);
        cd.bytes += bp;
    }
    
    private void addBytesProxiedForCountry(long bytes, InetAddress peerAddress) {
        GeoData geoData = lookupService.getGeoData(peerAddress);
        if (geoData != null) {
            String countryCode = geoData.getCountrycode();
            if ("IR".equals(countryCode)) {
                bytesProxiedForIran.addAndGet(bytes);
                globalBytesProxiedForIran.addAndGet(bytes);
            } else if ("CN".equals(countryCode)) {
                bytesProxiedForChina.addAndGet(bytes);
                globalBytesProxiedForChina.addAndGet(bytes);
            }
        }
    }
    
    @Override
    public long getBytesProxiedForIran() {
        return bytesProxiedForIran.getAndSet(0);
    }
    
    @Override
    public long getGlobalBytesProxiedForIran() {
        return globalBytesProxiedForIran.getAndSet(0);
    }
    
    @Override
    public long getBytesProxiedForChina() {
        return bytesProxiedForChina.getAndSet(0);
    }
    
    @Override
    public long getGlobalBytesProxiedForChina() {
        return globalBytesProxiedForChina.getAndSet(0);
    }
    @Override
    public void addProxiedClientAddress(InetAddress address) {
        distinctProxiedClientAddresses.add(address);
    }
    
    @Override
    public long getCountOfDistinctProxiedClientAddresses() {
        return distinctProxiedClientAddresses.size();
    }

    @Override
    public void setUpnp(final boolean upnp) {
        this.upnp = upnp;
    }

    @Override
    public boolean isUpnp() {
        return upnp;
    }

    @Override
    public void setNatpmp(final boolean natpmp) {
        this.natpmp = natpmp;
    }

    @Override
    public boolean isNatpmp() {
        return natpmp;
    }

    private CountryData toCountryData(final InetSocketAddress isa) {
        if (isa == null) {
            return null;
        }
        
        final InetAddress addr = isa.getAddress();
        final GeoData location = lookupService.getGeoData(addr);
        final String countryCode = location.getCountrycode();
        final Country country = countryService.getCountryByCode(countryCode);
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

    @Override
    public String getVersion() {
        return LanternClientConstants.VERSION;
    }
    
    @Keep
    public final class CountryData {
        private final Set<InetAddress> addresses = new HashSet<InetAddress>();
        private volatile long bytes;
        
        private final JSONObject lanternData = new JSONObject();
        final JSONObject data = new JSONObject();
        
        private CountryData(final Country country) {
            data.put("censored", country.isCensors());
            data.put("name", country.getName());
            data.put("code", country.getCode());
            data.put("lantern", lanternData);
        }
    }

    @Subscribe
    public void onReset(final ResetEvent event) {
        resetUserStats();
        resetCumulativeStats();
    }

    @Override
    public long getPeerCount() {
        //TODO: implement this (or remove it)
        return -1;
    }

    @Override
    public long getPeerCountThisRun() {
        //TODO: implement this (or remove it)
        return -1;
    }

    @Override
    public String getCountryCode() {
        return countryCode;
    }

    @Subscribe
    public void onLocationChanged(final LocationChangedEvent e) {
        countryCode = e.getNewCountry();
    }
}
