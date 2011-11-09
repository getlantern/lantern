package org.lantern;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.UnknownHostException;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

import org.apache.commons.io.IOUtils;
import org.jboss.netty.channel.Channel;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.littleshoot.util.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.maxmind.geoip.Country;
import com.maxmind.geoip.LookupService;

/**
 * Class for tracking all Lantern data.
 */
public class StatsTracker implements LanternData {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final AtomicLong bytesProxied = new AtomicLong(0L);
    
    private final AtomicLong directBytes = new AtomicLong(0L);
    
    private final AtomicInteger proxiedRequests = new AtomicInteger(0);
    
    private final AtomicInteger directRequests = new AtomicInteger(0);

    
    private final ConcurrentHashMap<String, CountryData> countries = 
        new ConcurrentHashMap<String, StatsTracker.CountryData>();
    
    public StatsTracker() {
        addOniData();
    }

    private void addOniData() {
        final File file = new File("oni/oni_country_data_2011-11-08.csv");
        BufferedReader br = null;
        try {
            br = new BufferedReader(
                new InputStreamReader(new FileInputStream(file)));
            String line = br.readLine();
            line = br.readLine();
            while (line != null) {
                addCountryData(line);
                line = br.readLine();
            }
        } catch (final IOException e) {
            log.error("No file?", e);
        } finally {
            IOUtils.closeQuietly(br);
        }
    }

    /*
    public void clear() {
        bytesProxied.set(0L);
        directBytes.set(0L);
        proxiedRequests.set(0);
        directRequests.set(0);
    }
    */

    private final int country_code = 0;
    private final int country_index = 1;
    private final int political_score = 2;
    private final int political_description = 3;
    private final int social_score = 4;
    private final int social_description = 5;
    private final int tools_score = 6;
    private final int tools_description = 7;
    private final int conflict_security_score = 8;
    private final int conflict_security_description = 9;
    private final int transparency = 10;
    private final int consistency = 11;
    private final int testing_date = 12;
    private final int url = 13;
    
    final JSONObject oniJson = new JSONObject();
    
    private void addCountryData(final String line) {
        final String[] data = line.split(",");
        final CountryData cd = 
            new CountryData(new Country(data[country_code], data[country_index]));
        
        final JSONObject json = new JSONObject();
        json.put("political", data[political_description]);
        json.put("social", data[social_description]);
        json.put("tools", data[tools_description]);
        json.put("conflict_security", data[conflict_security_description]);
        json.put("transparency", data[transparency]);
        json.put("consistency", data[consistency]);
        json.put("testing_date", data[testing_date]);
        json.put("url", data[url]);
        cd.oniJson = json;
        oniJson.put(data[country_code], json);
        countries.put(data[country_code], cd);
    }

    public void addBytesProxied(final long bp, final Channel channel) {
        bytesProxied.addAndGet(bp);
        final CountryData cd = toCountryData(channel);
        cd.bytes += bp;
    }

    public void addBytesProxied(final long bp, final Socket sock) {
        bytesProxied.addAndGet(bp);
        final CountryData cd = toCountryData(sock);
        cd.bytes += bp;
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
        private JSONObject oniJson;
        
        private final JSONObject lanternData = new JSONObject();
        
        private CountryData(final Country country) {
            this.country = country;
            lanternData.put("name", country.getName());
            lanternData.put("code", country.getCode());
        }

        private JSONObject toJson() {
            final JSONObject data = new JSONObject();
            lanternData.put("users", addresses.size());
            lanternData.put("proxied_bytes", bytes);
            lanternData.put("proxied_requests", requests);
            data.put("oni", oniJson);
            data.put("lantern", lanternData);
            return data;
        }
    }

    public String toJson() {
        final JSONObject json = new JSONObject();
        json.put("direct_bytes", directBytes);
        json.put("direct_requests", directRequests);
        json.put("proxied_bytes", bytesProxied);
        json.put("proxied_requests", proxiedRequests);
        
        final LookupService ls = LanternHub.getGeoIpLookup();
        try {
            final InetAddress ia = NetworkUtils.getLocalHost();
            final String homeland = ls.getCountry(ia).getCode();
            json.put("my_country", homeland);
        } catch (final UnknownHostException e) {
            log.error("Could not lookup localhost?", e);
        }
        
        final JSONArray countryData = new JSONArray();
        json.put("countries", countryData);
        synchronized (countries) {
            for (final CountryData cd : countries.values()) {
                countryData.add(cd.toJson());
            }
        }
        return json.toJSONString();
    }

    public String oniJson() {
        return this.oniJson.toJSONString();
    }

    public String countryData(final String countryCode) {
        final CountryData data = countries.get(countryCode);
        return data.toJson().toJSONString();
    }
}
