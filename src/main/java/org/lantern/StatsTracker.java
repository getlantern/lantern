package org.lantern;

import java.lang.management.ManagementFactory;
import java.lang.management.MemoryUsage;
import java.lang.management.OperatingSystemMXBean;
import java.lang.reflect.Method;
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

    private double processCpuUsage;

    private double systemCpuUsage;

    private double systemLoadAverage;

    private double memoryUsageInBytes;

    private long numberOfOpenFileDescriptors;

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
    public void addDownBytesFromPeers(final long bp) {
        downBytesPerSecondFromPeers.add(bp);
        log.debug("downBytesPerSecondFromPeers += {} down-rate {}", bp, getDownBytesPerSecond());
    }
    
    @Override
    public void addUpBytesToPeers(final long bp) {
        upBytesPerSecondToPeers.add(bp);
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

    @Override
    public double getProcessCpuUsage() {
        return processCpuUsage;
    }

    @Override
    public double getSystemCpuUsage() {
        return systemCpuUsage;
    }

    @Override
    public double getSystemLoadAverage() {
        return systemLoadAverage;
    }

    @Override
    public double getMemoryUsageInBytes() {
        return memoryUsageInBytes;
    }

    @Override
    public long getNumberOfOpenFileDescriptors() {
        return numberOfOpenFileDescriptors;
    }

    @Override
    public void updateSystemStatistics() {
        // Below courtesy of:
        // http://stackoverflow.com/questions/10999076/programmatically-print-the-heap-usage-that-is-typically-printed-on-jvm-exit-when
        MemoryUsage mu = ManagementFactory.getMemoryMXBean()
                .getHeapMemoryUsage();
        MemoryUsage muNH = ManagementFactory.getMemoryMXBean()
                .getNonHeapMemoryUsage();
        this.memoryUsageInBytes = mu.getCommitted() + muNH.getCommitted();

        // Below courtesy of:
        // http://neopatel.blogspot.com/2011/05/java-count-open-file-handles.html
        OperatingSystemMXBean osStats = ManagementFactory
                .getOperatingSystemMXBean();
        this.systemLoadAverage = osStats.getSystemLoadAverage();
        if (osStats.getClass().getName()
                .equals("com.sun.management.UnixOperatingSystem")) {
            this.processCpuUsage = getSystemStatDouble(osStats, "getProcessCpuLoad");
            this.systemCpuUsage = getSystemStatDouble(osStats, "getSystemCpuLoad");
            this.numberOfOpenFileDescriptors = getSystemStatLong(osStats, "getOpenFileDescriptorCount");
        }
    }

    private Double getSystemStatDouble(final OperatingSystemMXBean osStats, 
            final String name) {
        try {
            return getSystemStat(osStats, name);
        } catch (final Exception e) {
            log.debug("Unable to get system stat: {}", name, e);
            return 0.0;
        }
    }
    
    private Long getSystemStatLong(final OperatingSystemMXBean osStats, 
            final String name) {
        try {
            return getSystemStat(osStats, name);
        } catch (final Exception e) {
            log.debug("Unable to get system stat: {}", name, e);
            return 0L;
        }
    }
    
    @SuppressWarnings("unchecked")
    private <T extends Number> T getSystemStat(
            final OperatingSystemMXBean osStats, 
            final String name) throws Exception {
        final  Method method = osStats.getClass().getDeclaredMethod(name);
        method.setAccessible(true);
        return (T) method.invoke(osStats);
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
