package org.lantern;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.jboss.netty.channel.Channel;

import com.maxmind.geoip.Country;
import com.maxmind.geoip.LookupService;

/**
 * Class for tracking all Lantern data.
 */
public class StatsTracker implements LanternData {
    
    private volatile long bytesProxied;
    
    private volatile long directBytes;

    private volatile int proxiedRequests;

    private volatile int directRequests;
    
    private final ConcurrentHashMap<String, CountryData> countries = 
        new ConcurrentHashMap<String, StatsTracker.CountryData>();
    
    public StatsTracker() {}

    public void clear() {
        bytesProxied = 0L;
        directBytes = 0L;
        proxiedRequests = 0;
        directRequests = 0;
    }

    public void addBytesProxied(final long bp, final Channel channel) {
        bytesProxied += bp;
        final CountryData cd = toCountryData(channel);
        cd.bytes += bp;
    }
    
    @Override
    public long getTotalBytesProxied() {
        return bytesProxied;
    }

    public void addDirectBytes(final int db) {
        directBytes += db;
    }

    @Override
    public long getDirectBytes() {
        return directBytes;
    }

    public void incrementDirectRequests() {
        this.directRequests++;
    }

    public void incrementProxiedRequests(final Channel channel) {
        this.proxiedRequests++;
        final CountryData cd = toCountryData(channel);
        cd.requests++;
    }

    @Override
    public int getTotalProxiedRequests() {
        return proxiedRequests;
    }

    @Override
    public int getDirectRequests() {
        return directRequests;
    }

    private CountryData toCountryData(final Channel channel) {
        final LookupService ls = LanternHub.getGeoIpLookup();
        final InetSocketAddress isa = 
            (InetSocketAddress) channel.getRemoteAddress();
        final InetAddress addr = isa.getAddress();
        final Country country = ls.getCountry(addr);
        final CountryData cd = 
            countries.putIfAbsent(country.getCode(), new CountryData(country));
        
        cd.addresses.add(addr);
        return cd;
    }

    private static final class CountryData {
        private final Set<InetAddress> addresses = new HashSet<InetAddress>();
        private volatile int requests;
        private volatile long bytes;
        private final Country country;
        
        private CountryData(final Country country) {
            this.country = country;
        }
    }
}
