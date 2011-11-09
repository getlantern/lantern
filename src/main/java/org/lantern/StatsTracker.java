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
    
    private static final JSONObject googleRemoveProductAndReasonJson = new JSONObject();
    private static final JSONObject googleRemovalJson = new JSONObject();
    private static final JSONObject googleRemovalByProductJson = new JSONObject();
    private static final JSONObject googleUserDataJson = new JSONObject();
    
    
    private static final ConcurrentHashMap<String, CountryData> countries = 
        new ConcurrentHashMap<String, StatsTracker.CountryData>();
    
    /**
     * Censored country codes, in order of population.
     */
    public static final Collection<String> CENSORED = new HashSet<String>();
    
    static {
        // Adding Cuba and North Korea since ONI has no data for them but they
        // seem to clearly censor.
        CENSORED.add("CU");
        CENSORED.add("KP");
        addOniData();
        final String[] columnNames0 = {
            "Period Ending", 
            "Country", 
            "Country Code", 
            "Content Removal Requests", 
            "Percentage of removal requests fully or partially complied with", 
            "Items Requested To Be Removed"
        };
        addGoogleData(columnNames0, 
            "google-content-removal-requests.csv", 2, 1, 
            googleRemovalJson);
        
        final String[] columnNames1 = {
            "Period Ending",
            "Country",
            "Country Code",
            "Product",
            "Reason",
            "Court Orders",
            "Executive, Police, etc.", 
            "Items Requested To Be Removed",
        };
        parseCsv(columnNames1, 
            "google-content-removal-requests-by-product-and-reason.csv", 2, 1, 
            googleRemoveProductAndReasonJson);
        
        final String[] columnNames3 = {
            "Period Ending","Country","Country Code","Product",
            "Court Orders","Executive, Police, etc.",
            "Items Requested To Be Removed",
        };
        addGoogleData(columnNames3, 
            "google-content-removal-requests-by-product.csv", 2, 1, 
            googleRemovalByProductJson);
        
        final String[] columnNames4 = {
            "Period Ending", "Country", "Country Code", "Data Requests", 
            "Percentage of data requests fully or partially complied with", 
            "Users/Accounts Specified"
        };
        addGoogleData(columnNames4, 
            "google-user-data-requests.csv", 2, 1, 
            googleUserDataJson);
        
    }

    public StatsTracker() {
    }

    private static void parseCsv(final String[] columnNames, 
        final String fileName, final int countryCodeIndex, 
        final int countryNameIndex, final JSONObject json) {
        final File file = new File("data/"+fileName);
        BufferedReader br = null;
        try {
            br = new BufferedReader(
                new InputStreamReader(new FileInputStream(file)));
            String line = br.readLine();
            line = br.readLine();
            while (line != null) {
                addCountrySubCsvData(columnNames, line, fileName, 
                    countryCodeIndex, countryNameIndex, json);
                line = br.readLine();
            }
        } catch (final IOException e) {
            log.error("No file?", e);
        } finally {
            IOUtils.closeQuietly(br);
        }
    }
    
    private static void addGoogleData(final String[] columnNames, 
        final String fileName, final int countryCodeIndex, 
        final int countryNameIndex, final JSONObject json) {
        final File file = new File("data/"+fileName);
        BufferedReader br = null;
        try {
            br = new BufferedReader(
                new InputStreamReader(new FileInputStream(file)));
            String line = br.readLine();
            line = br.readLine();
            while (line != null) {
                addGenericCsvData(columnNames, line, fileName, 
                   countryCodeIndex, countryNameIndex, json);
                line = br.readLine();
            }
        } catch (final IOException e) {
            log.error("No file?", e);
        } finally {
            IOUtils.closeQuietly(br);
        }
    }

    private static void addOniData() {
        final File file = new File("data/oni_country_data_2011-11-08.csv");
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
    
    private static void addCountrySubCsvData(final String[] columnNames, 
        final String lineParam, final String name, final int countryCodeIndex,
        final int countryNameIndex, final JSONObject global) {
        final String line;
        if (lineParam.endsWith(",")) {
            line = lineParam +"0";
        } else {
            line = lineParam;
        }
        final String[] data = line.split(",");
        final String cc = data[countryCodeIndex];
        final String countryName = data[countryNameIndex];

        
        final JSONObject json = new JSONObject();
        
        for (int i = 5; i < columnNames.length; i++) {
            json.put(columnNames[i], data[i]);
        }
        
        //google.put(name, json);
        final JSONObject countryObject;
        if (!global.containsKey(cc)) {
            countryObject = new JSONObject();
            global.put(cc, countryObject);
        } else {
            countryObject = (JSONObject) global.get(cc);
        }
        final CountryData cd = newCountryData(cc, countryName);
        cd.data.put(name, countryObject);
        
        final JSONObject productObject;
        if (!countryObject.containsKey(name)) {
            productObject = new JSONObject();
            if (cc.equals("NO")) {
                System.out.println("Adding "+data[3]+" to country object");
            }
            countryObject.put(data[3], productObject);
        } else {
            productObject = (JSONObject) countryObject.get(data[3]);
        }
        
        productObject.put(data[4], json);
    }

    private static void addUserCsvData(final String[] columnNames, 
        final String lineParam, final String name, final int countryCodeIndex,
        final int countryNameIndex, final JSONObject global) {
        final String line;
        if (lineParam.endsWith(",")) {
            line = lineParam +"0";
        } else {
            line = lineParam;
        }
        final String[] data = line.split(",");
        final String cc = data[countryCodeIndex];
        
        final String countryName = data[countryNameIndex];
        
        final JSONObject json = new JSONObject();
        
        for (int i = 0; i < columnNames.length; i++) {
            json.put(columnNames[i], data[i]);
        }
        
        //google.put(name, json);
        global.put(cc, json);

        final CountryData cd = newCountryData(cc, countryName);
        final JSONObject country;
        cd.data.put(name, json);
        //countries.put(cc, cd);
    }
    
    private static void addGenericCsvData(final String[] columnNames, 
        final String lineParam, final String name, final int countryCodeIndex,
        final int countryNameIndex, final JSONObject global) {
        final String line;
        if (lineParam.endsWith(",")) {
            line = lineParam +"0";
        } else {
            line = lineParam;
        }
        final String[] data = line.split(",");
        final String cc = data[countryCodeIndex];
        
        final String countryName = data[countryNameIndex];
        
        final JSONObject json = new JSONObject();
        
        for (int i = 3; i < columnNames.length; i++) {
            json.put(columnNames[i], data[i]);
        }
        
        //google.put(name, json);
        global.put(cc, json);

        final CountryData cd = newCountryData(cc, countryName);
        cd.data.put(name, json);
        //countries.put(cc, cd);
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
        
        final JSONObject json = new JSONObject();
        json.put("political", data[political_description]);
        json.put("social", data[social_description]);
        json.put("tools", data[tools_description]);
        json.put("conflict_security", data[conflict_security_description]);
        json.put("transparency", data[transparency]);
        json.put("consistency", data[consistency]);
        json.put("testing_date", data[testing_date]);
        json.put("url", data[url]);
        
        oniJson.put(cc, json);
        
        final CountryData cd = newCountryData(cc, name);

        if (cc.equals("NO")) {
            System.out.println("Adding ONI data to: "+cd.hashCode());
        }
        cd.data.put("oni", json);
    }

    private static CountryData newCountryData(final String cc, 
        final String name) {
        if (countries.containsKey(cc)) {
            return countries.get(cc);
        } 
        if (cc.equals("NO")) {
            System.out.println("Adding new country data for Norway!!");
        }
        final Country co = new Country(cc, name);
        final CountryData cd = new CountryData(co);
        countries.put(cc, cd);
        return cd;
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
            data.put("censored", CensoredUtils.isCensored(country));
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
        return oniJson.toJSONString();
    }

    public String countryData(final String countryCode) {
        final CountryData data = countries.get(countryCode);
        return data.toJson().toJSONString();
    }

    public String googleContentRemovalProductReason() {
        return googleRemoveProductAndReasonJson.toJSONString();
    }

    public String googleContentRemovalRequests() {
        return googleRemovalJson.toJSONString();
    }
}
