package org.lantern;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.log4j.Logger;

public class GeoData {
    private static final Logger LOGGER = Logger.getLogger(GeoData.class);

    private static final Map<String, Double> LATITUDES_BY_COUNTRY = new ConcurrentHashMap<String, Double>();
    private static final Map<String, Double> LONGITUDES_BY_COUNTRY = new ConcurrentHashMap<String, Double>();

    static {
        // This parses a file obtained from
        // http://dev.maxmind.com/geoip/legacy/codes/average-latitude-and-longitude-for-countries/
        // that gives average lat/lon per 2 digit country code.
        BufferedReader reader = null;
        try {
            reader = new BufferedReader(new InputStreamReader(
                    GeoData.class.getResourceAsStream("/country_latlon.csv")));
            String line = null;
            boolean first = true;
            while ((line = reader.readLine()) != null) {
                if (!first) {
                    String[] row = line.split(",");
                    LATITUDES_BY_COUNTRY.put(row[0], new Double(row[1]));
                    LONGITUDES_BY_COUNTRY.put(row[0], new Double(row[2]));
                }
                first = false;
            }
        } catch (Exception e) {
            LOGGER.error(
                    "Unable to load default latitude and longitude by country",
                    e);
        } finally {
            if (reader != null) {
                try {
                    reader.close();
                } catch (Exception e) {
                    // ignore
                }
            }
        }
    }

    private String countrycode = "";

    private double latitude = 0.0;

    private double longitude = 0.0;

    public GeoData() {
    }

    public GeoData(com.maxmind.geoip.Country country) {
        this(country != null ? country.getCode() : null, 0, 0);
    }

    public GeoData(String countrycode, double latitude, double longitude) {
        super();
        this.countrycode = countrycode != null ? countrycode : "00";
        this.latitude = latitude;
        this.longitude = longitude;
        // Default latitude and longitude by country code if necessary
        if (countrycode != null) {
            if (latitude == 0) {
                Double val = LATITUDES_BY_COUNTRY.get(countrycode);
                this.latitude = val != null ? val : 0.0;
            }
            if (longitude == 0) {
                Double val = LONGITUDES_BY_COUNTRY.get(countrycode);
                this.longitude = val != null ? val : 0.0;
            }
        }
    }

    public double getLatitude() {
        return latitude;
    }

    public void setLatitude(double latitude) {
        this.latitude = latitude;
    }

    public double getLongitude() {
        return longitude;
    }

    public void setLongitude(double longitude) {
        this.longitude = longitude;
    }

    public String getCountrycode() {
        return countrycode;
    }

    public void setCountrycode(String countrycode) {
        this.countrycode = countrycode.toUpperCase();
    }

    @Override
    public String toString() {
        return "GeoData [countryCode=" + getCountrycode() + ", latitude="
                + latitude
                + ", longitude=" + longitude + "]";
    }
}
