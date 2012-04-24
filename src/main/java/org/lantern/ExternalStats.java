package org.lantern;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;

import org.apache.commons.io.IOUtils;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * This also displays data from the Google Transparency Report and ONI.
 */
public class ExternalStats {

    private static final Logger log = 
        LoggerFactory.getLogger(ExternalStats.class);
    
    private static final JSONObject oniJson = new JSONObject();
    
    private static final JSONObject googleRemoveProductAndReasonJson = 
        new JSONObject();
    private static final JSONObject googleRemovalJson = 
        new JSONObject();
    private static final JSONObject googleRemovalByProductJson = 
        new JSONObject();
    private static final JSONObject googleUserDataJson = 
        new JSONObject();

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
        final StatsTracker.CountryData cd = StatsTracker.newCountryData(cc, countryName);
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

        final StatsTracker.CountryData cd = StatsTracker.newCountryData(cc, countryName);
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

        final StatsTracker.CountryData cd = StatsTracker.newCountryData(cc, countryName);
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
        
        final StatsTracker.CountryData cd = StatsTracker.newCountryData(cc, name);

        cd.data.put("oni", json);
    }

    public String oniJson() {
        return oniJson.toJSONString();
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
