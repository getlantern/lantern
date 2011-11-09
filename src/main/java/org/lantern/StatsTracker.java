package org.lantern;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.Collection;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

import org.apache.commons.io.IOUtils;
import org.jboss.netty.channel.Channel;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.lastbamboo.common.stun.client.PublicIpAddress;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.maxmind.geoip.Country;
import com.maxmind.geoip.LookupService;

/**
 * Class for tracking all Lantern data.
 */
public class StatsTracker implements LanternData {
    
    private final static Logger log = 
        LoggerFactory.getLogger(StatsTracker.class);
    
    private final AtomicLong bytesProxied = new AtomicLong(0L);
    
    private final AtomicLong directBytes = new AtomicLong(0L);
    
    private final AtomicInteger proxiedRequests = new AtomicInteger(0);
    
    private final AtomicInteger directRequests = new AtomicInteger(0);

    private static final JSONObject oniJson = new JSONObject();
    
    
    private static final ConcurrentHashMap<String, CountryData> countries = 
        new ConcurrentHashMap<String, StatsTracker.CountryData>();
    
    /**
     * Censored country codes, in order of population.
     */
    public static final Collection<String> CENSORED =
        new HashSet<String>();
    
    static {
        // Adding Cuba and North Korea since ONI has no data for them but they
        // seem to clearly censor.
        CENSORED.add("CU");
        CENSORED.add("KP");
        addOniData();
    }
/*
    Sets.newHashSet(
            // Asia 
            "CN",
            "VN",
            "MM",
            //Mideast: 
            "IR", 
            "BH", // Bahrain
            "YE", // Yemen
            "SA", // Saudi Arabia
            "SY",
            //Eurasia: 
            "UZ", // Uzbekistan
            "TM", // Turkmenistan
            //Africa: 
            "ET", // Ethiopia
            "ER", // Eritrea
            // LAC: 
            "CU");
            */

    public StatsTracker() {
    }

    private static void addOniData() {
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

    private static final int country_code = 0;
    private static final int country_index = 1;
    private static final int political_score = 2;
    private static final int political_description = 3;
    private static final int social_score = 4;
    private static final int social_description = 5;
    private static final int tools_score = 6;
    private static final int tools_description = 7;
    private static final int conflict_security_score = 8;
    private static final int conflict_security_description = 9;
    private static final int transparency = 10;
    private static final int consistency = 11;
    private static final int testing_date = 12;
    private static final int url = 13;
    
    private static void addCountryData(final String line) {
        //final boolean censored = line.contains("pervasive");
        final boolean censored = 
            line.contains("pervasive") || 
            line.contains("substantial");
        final String[] data = line.split(",");
        final String cc = data[country_code];
        final String name = data[country_index];
        //System.out.println("Adding line: "+line);
        //System.out.println("CC: "+cc);
        if (censored) {
            System.out.println("CENSORED: "+name+ " CC: "+cc);
            CENSORED.add(cc);
        }
        final Country co = new Country(cc, name);
        final CountryData cd = new CountryData(co, censored);
        
        final JSONObject json = new JSONObject();
        json.put("political", data[political_description]);
        json.put("social", data[social_description]);
        json.put("tools", data[tools_description]);
        json.put("conflict_security", data[conflict_security_description]);
        json.put("transparency", data[transparency]);
        json.put("consistency", data[consistency]);
        json.put("testing_date", data[testing_date]);
        json.put("url", data[url]);
        cd.data.put("oni", json);
        oniJson.put(cc, json);
        countries.put(cc, cd);
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
        
        private final JSONObject lanternData = new JSONObject();
        final JSONObject data = new JSONObject();
        
        private CountryData(final Country country) {
            this(country, CensoredUtils.isCensored(country));
        }
        
        private CountryData(final Country country, final boolean censored) {
            data.put("censored", censored);
            data.put("name", country.getName());
            data.put("code", country.getCode());
            data.put("lantern", lanternData);
        }

        private JSONObject toJson() {
            lanternData.put("users", addresses.size());
            lanternData.put("proxied_bytes", bytes);
            lanternData.put("proxied_requests", requests);

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
        final InetAddress ia = new PublicIpAddress().getPublicIpAddress();
        final String homeland = ls.getCountry(ia).getCode();
        json.put("my_country", homeland);
        
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
