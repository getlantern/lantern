package org.lantern;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
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

import com.maxmind.geoip.LookupService;

/**
 * Class for tracking all Lantern data. This also displays data from the 
 * Google Transparency Report and ONI.
 */
public class StatsTracker implements LanternData {
    
    private final static Logger log = 
        LoggerFactory.getLogger(StatsTracker.class);
    
    private final AtomicLong bytesProxied = new AtomicLong(0L);
    
    private final AtomicLong directBytes = new AtomicLong(0L);
    
    private final AtomicInteger proxiedRequests = new AtomicInteger(0);
    
    private final AtomicInteger directRequests = new AtomicInteger(0);

    private static final JSONObject oniJson = new JSONObject();
    
    private static final JSONObject googleRemoveProductAndReasonJson = 
        new JSONObject();
    private static final JSONObject googleRemovalJson = 
        new JSONObject();
    private static final JSONObject googleRemovalByProductJson = 
        new JSONObject();
    private static final JSONObject googleUserDataJson = 
        new JSONObject();
    
    
    /** 
     * getXYZBytesPerSecond calls will be calculated using a moving 
     * window average of size DATA_RATE_SECONDS.
     */ 
    private static final int DATA_RATE_SECONDS = 1;
    private static final int ONE_SECOND = 1000;
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


    
    private static final ConcurrentHashMap<String, CountryData> countries = 
        new ConcurrentHashMap<String, StatsTracker.CountryData>();
    
    static {
        // Adding Cuba and North Korea since ONI has no data for them but they
        // seem to clearly censor.
        //CensoredUtils.CENSORED.add("CU");
        //CensoredUtils.CENSORED.add("KP");
        
        /*
        addOniData();
        final String[] columnNames0 = {
            "Period Ending", 
            "Country", 
            "Country Code", 
            "Content Removal Requests", 
            "Percentage of removal requests fully or partially complied with", 
            "Items Requested To Be Removed"
        };
        addGenericGoogleData(columnNames0, 
            "google-content-removal-requests.csv", 2, 1, 
            googleRemovalJson);
        
        final String[] columnNames3 = {
            "Period Ending","Country","Country Code","Product",
            "Court Orders","Executive, Police, etc.",
            "Items Requested To Be Removed",
        };
        addGenericGoogleData(columnNames3, 
            "google-content-removal-requests-by-product.csv", 2, 1, 
            googleRemovalByProductJson);
        
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
        
        addGoogleProductAndReason(columnNames1, 
            "google-content-removal-requests-by-product-and-reason.csv", 2, 1, 
            googleRemoveProductAndReasonJson);
        
        
        final String[] columnNames4 = {
            "Period Ending", "Country", "Country Code", "Data Requests", 
            "Percentage of data requests fully or partially complied with", 
            "Users/Accounts Specified"
        };
        addGoogleUserData(columnNames4, 
            "google-user-data-requests.csv", 2, 1, 
            googleUserDataJson);
            */
        
    }

    public StatsTracker() {}

    private static void addGoogleProductAndReason(final String[] columnNames, 
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
                addGoogleProductAndReasonData(columnNames, line, fileName, 
                    countryCodeIndex, countryNameIndex, json);
                line = br.readLine();
            }
        } catch (final IOException e) {
            log.error("No file?", e);
        } finally {
            IOUtils.closeQuietly(br);
        }
    }
    
    private static void addGoogleUserData(final String[] columnNames, 
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
                addUserCsvData(columnNames, line, fileName, 
                   countryCodeIndex, countryNameIndex, json);
                line = br.readLine();
            }
        } catch (final IOException e) {
            log.error("No file?", e);
        } finally {
            IOUtils.closeQuietly(br);
        }
    }

    private static void addGenericGoogleData(final String[] columnNames, 
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
                addGenericGoogleCsvData(columnNames, line, fileName, 
                   countryCodeIndex, countryNameIndex, json);
                line = br.readLine();
            }
        } catch (final IOException e) {
            log.error("No file?", e);
        } finally {
            IOUtils.closeQuietly(br);
        }
    }

    static void addOniData() {
        final File file = new File("data/oni_country_data_2011-11-08.csv");
        BufferedReader br = null;
        try {
            br = new BufferedReader(
                new InputStreamReader(new FileInputStream(file)));
            String line = br.readLine();
            line = br.readLine();
            while (line != null) {
                addOniCountryData(line);
                line = br.readLine();
            }
            //log.info("CENSORED COUNTRIES:\n{}",LanternHub.settings().censored().getCensored());
        } catch (final IOException e) {
            log.error("No file?", e);
        } finally {
            IOUtils.closeQuietly(br);
        }
    }
    
    private static void addGoogleProductAndReasonData(final String[] columnNames, 
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
        final String key = "user-requests";
        final JSONArray userRequests;
        if (cd.data.containsKey(key)) {
            userRequests = (JSONArray) cd.data.get(key);
        } else {
            userRequests = new JSONArray();
            cd.data.put(key, userRequests);
        }
        userRequests.add(json);
    }
    
    private static void addGenericGoogleCsvData(final String[] columnNames, 
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
        
        global.put(cc, json);

        final CountryData cd = newCountryData(cc, countryName);
        cd.data.put(name, json);
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
    
    private static void addOniCountryData(final String line) {
        // We define a country as "censored" if it has any "pervasive" or
        // "substantial" censorship according to ONI.
        final boolean censored = 
            line.contains("pervasive") || 
            line.contains("substantial");
        final String[] data = line.split(",");
        final String cc = data[country_code];
        final String name = data[country_index];
        if (censored) {
            //LanternHub.settings().censored().getCensored().add(cc);
            
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

        cd.data.put("oni", json);
    }

    private static CountryData newCountryData(final String cc, 
        final String name) {
        if (countries.containsKey(cc)) {
            return countries.get(cc);
        } 
        final Country co = new Country(cc, name);
        final CountryData cd = new CountryData(co);
        countries.put(cc, cd);
        return cd;
    }
    
    public void resetUserStats() {
        upBytesPerSecondViaProxies.resetLifetimeTotal();
        downBytesPerSecondViaProxies.resetLifetimeTotal();
        upBytesPerSecondForPeers.resetLifetimeTotal();
        downBytesPerSecondForPeers.resetLifetimeTotal();
        upBytesPerSecondToPeers.resetLifetimeTotal();
        downBytesPerSecondFromPeers.resetLifetimeTotal();
        // others?
    }
    
    public long getUpBytesThisRun() {
        return getUpBytesThisRunForPeers() + // requests uploaded to internet for peers
               getUpBytesThisRunViaProxies() + // requests sent to other proxies
               getUpBytesThisRunToPeers();   // responses to requests we proxied
    }
    
    public long getDownBytesThisRun() {
        return getDownBytesThisRunForPeers() + // downloaded from internet for peers
               getDownBytesThisRunViaProxies() + // replys to requests proxied by others
               getDownBytesThisRunFromPeers(); // requests from peers        
    }
    
    public long getUpBytesThisRunForPeers() {
        return upBytesPerSecondForPeers.lifetimeTotal();
    }
    
    public long getUpBytesThisRunViaProxies() {
        return upBytesPerSecondViaProxies.lifetimeTotal();
    }

    public long getUpBytesThisRunToPeers() {
        return upBytesPerSecondToPeers.lifetimeTotal();
    }
    
    public long getDownBytesThisRunForPeers() {
        return downBytesPerSecondForPeers.lifetimeTotal();
    }

    public long getDownBytesThisRunViaProxies() {
        return downBytesPerSecondViaProxies.lifetimeTotal();
    }

    public long getDownBytesThisRunFromPeers() {
        return downBytesPerSecondFromPeers.lifetimeTotal();
    }
    
    
    public long getUpBytesPerSecond() {
        return getUpBytesPerSecondForPeers() + // requests uploaded to internet for peers
               getUpBytesPerSecondViaProxies() + // requests sent to other proxies
               getUpBytesPerSecondToPeers();   // responses to requests we proxied
    }

    public long getDownBytesPerSecond() {
        return getDownBytesPerSecondForPeers() + // downloaded from internet for peers
               getDownBytesPerSecondViaProxies() + // replys to requests proxied by others
               getDownBytesPerSecondFromPeers(); // requests from peers
    }
    
    public long getUpBytesPerSecondForPeers() {
        return getBytesPerSecond(upBytesPerSecondForPeers);
    }

    public long getUpBytesPerSecondViaProxies() {
        return getBytesPerSecond(upBytesPerSecondViaProxies);
    }

    public long getDownBytesPerSecondForPeers() {
        return getBytesPerSecond(downBytesPerSecondForPeers);
    }
    
    public long getDownBytesPerSecondViaProxies() {
        return getBytesPerSecond(downBytesPerSecondViaProxies);
    }
    
    public long getDownBytesPerSecondFromPeers() {
        return getBytesPerSecond(downBytesPerSecondFromPeers);
    }
    
    public long getUpBytesPerSecondToPeers() {
        return getBytesPerSecond(upBytesPerSecondToPeers);
    }
    
    private long getBytesPerSecond(TimeSeries1D ts) {
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
    public void addUpBytesViaProxies(final long bp, final Channel channel) {
        upBytesPerSecondViaProxies.addData(bp);
        log.debug("upBytesPerSecondViaProxies += {} up-rate {}", bp, getUpBytesPerSecond());
    }

    /**
     * request bytes this lantern proxy sent to other lanterns for proxying
     */
    public void addUpBytesViaProxies(final long bp, final Socket sock) {
        upBytesPerSecondViaProxies.addData(bp);
        log.debug("upBytesPerSecondViaProxies += {} up-rate {}", bp, getUpBytesPerSecond());
    }

    /**
     * bytes sent upstream on behalf of another lantern by this
     * lantern
     */
    public void addUpBytesForPeers(final long bp, final Channel channel) {
        upBytesPerSecondForPeers.addData(bp);
        log.debug("upBytesPerSecondForPeers += {} up-rate {}", bp, getUpBytesPerSecond());
    }

    /**
     * bytes sent upstream on behalf of another lantern by this
     * lantern
     */
    public void addUpBytesForPeers(final long bp, final Socket sock) {
        upBytesPerSecondForPeers.addData(bp);
        log.debug("upBytesPerSecondForPeers += {} up-rate {}", bp, getUpBytesPerSecond());
    }

    /**
     * response bytes downloaded by Peers for this lantern
     */
    public void addDownBytesViaProxies(final long bp, final Channel channel) {
        downBytesPerSecondViaProxies.addData(bp);
        log.debug("downBytesPerSecondViaProxies += {} down-rate {}", bp, getDownBytesPerSecond());
    }

    /**
     * response bytes downloaded by Peers for this lantern
     */
    public void addDownBytesViaProxies(final long bp, final Socket sock) {
        downBytesPerSecondViaProxies.addData(bp);
        log.debug("downBytesPerSecondViaProxies += {} down-rate {}", bp, getDownBytesPerSecond());
    }

    /**
     * bytes downloaded on behalf of another lantern by this
     * lantern
     */
    public void addDownBytesForPeers(final long bp, final Channel channel) {
        downBytesPerSecondForPeers.addData(bp);
        log.debug("downBytesPerSecondForPeers += {} down-rate {}", bp, getDownBytesPerSecond());
    }
    /**
     * bytes downloaded on behalf of another lantern by this
     * lantern
     */
    public void addDownBytesForPeers(final long bp, final Socket sock) {
        downBytesPerSecondForPeers.addData(bp);
        log.debug("downBytesPerSecondForPeers += {} down-rate {}", bp, getDownBytesPerSecond());
    }
    
    /**
     * request bytes sent by peers to this lantern
     */
    public void addDownBytesFromPeers(final long bp, final Channel channel) {
        downBytesPerSecondFromPeers.addData(bp);
        log.debug("downBytesPerSecondFromPeers += {} down-rate {}", bp, getDownBytesPerSecond());
    }
    /**
     * request bytes sent by peers to this lantern
     */
    public void addDownBytesFromPeers(final long bp, final Socket sock) {
        downBytesPerSecondFromPeers.addData(bp);
        log.debug("downBytesPerSecondFromPeers += {} down-rate {}", bp, getDownBytesPerSecond());
    }
    
    /** 
     * reply bytes send to peers by this lantern
     */
    public void addUpBytesToPeers(final long bp, final Channel channel) {
        upBytesPerSecondToPeers.addData(bp);
        log.debug("upBytesPerSecondToPeers += {} up-rate {}", bp, getUpBytesPerSecond());
    }
    /** 
     * reply bytes send to peers by this lantern
     */
    public void addUpBytesToPeers(final long bp, final Socket sock) {
        upBytesPerSecondToPeers.addData(bp);
        log.debug("upBytesPerSecondToPeers += {} up-rate {}", bp, getUpBytesPerSecond());
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

    private static final class CountryData {
        private final Set<InetAddress> addresses = new HashSet<InetAddress>();
        private volatile int requests;
        private volatile long bytes;
        
        private final JSONObject lanternData = new JSONObject();
        final JSONObject data = new JSONObject();
        
        private CountryData(final Country country) {
            data.put("censored", LanternHub.censored().isCensored(country));
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
        log.info("Accessing data for country: '{}'", countryCode);
        final CountryData data = countries.get(countryCode.trim());
        return data.toJson().toJSONString();
    }

    public String googleContentRemovalProductReason() {
        return googleRemoveProductAndReasonJson.toJSONString();
    }

    public String googleContentRemovalRequests() {
        return googleRemovalJson.toJSONString();
    }

    public String googleUserRequests() {
        return googleUserDataJson.toJSONString();
    }
    
    public String googleRemovalByProductRequests() {
        return googleRemovalByProductJson.toJSONString();
    }
}
