package org.lantern;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.jboss.netty.channel.Channel;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;

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
    

    public void addBytesProxied(final long bp, final Socket sock) {
        bytesProxied += bp;
        final CountryData cd = toCountryData(sock);
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

    public void incrementProxiedRequests() {
        this.proxiedRequests++;
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
        final LookupService ls = LanternHub.getGeoIpLookup();
        final InetAddress addr = isa.getAddress();
        final Country country = ls.getCountry(addr);
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

    private static final class CountryData {
        private final Set<InetAddress> addresses = new HashSet<InetAddress>();
        private volatile int requests;
        private volatile long bytes;
        private final Country country;
        
        private CountryData(final Country country) {
            this.country = country;
        }
    }

    public String toJson() {
        final JSONObject json = new JSONObject();
        json.put("direct_bytes", directBytes);
        json.put("direct_requests", directRequests);
        json.put("proxied_bytes", bytesProxied);
        json.put("proxied_requests", proxiedRequests);
        
        final JSONArray countryData = new JSONArray();
        json.put("countries", countryData);
        synchronized (countries) {
            for (final CountryData cd : countries.values()) {
                final JSONObject data = new JSONObject();
                data.put("name", cd.country.getName());
                data.put("code", cd.country.getCode());
                data.put("users", cd.addresses.size());
                data.put("proxied_bytes", bytesProxied);
                data.put("proxied_requests", proxiedRequests);
                
                countryData.add(data);
            }
        }
        
        return json.toJSONString();
    }
}
