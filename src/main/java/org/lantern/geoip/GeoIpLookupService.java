package org.lantern.geoip;

import java.net.InetAddress;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.lang3.SystemUtils;
import org.lantern.GeoData;

import com.google.inject.Singleton;
import com.maxmind.geoip.LookupService;

/**
 * Service for GeoLocating. Uses MaxMind's {@link LookupService} internally.
 */
@Singleton
public class GeoIpLookupService {
    private final LookupService lookupService;
    private final Map<InetAddress, GeoData> addressLookupCache =
            new ConcurrentHashMap<InetAddress, GeoData>();
    private final Map<String, GeoData> stringLookupCache =
            new ConcurrentHashMap<String, GeoData>();

    public GeoIpLookupService() {
        try {
            this.lookupService = new LookupService(
                    SystemUtils.USER_DIR + "/GeoIP.dat");
        } catch (Exception e) {
            throw new Error(String.format(
                    "Unable to initialize GeoIpLookupService: %1$s",
                    e.getMessage()), e);
        }
    }

    public GeoData getGeoData(InetAddress ipAddress) {
        GeoData result = addressLookupCache.get(ipAddress);
        if (result == null) {
            result = new GeoData(lookupService.getCountry(ipAddress));
            addressLookupCache.put(ipAddress, result);
        }
        return result;
    }

    public GeoData getGeoData(String ipAddress) {
        GeoData result = stringLookupCache.get(ipAddress);
        if (result == null) {
            result = new GeoData(lookupService.getCountry(ipAddress));
            stringLookupCache.put(ipAddress, result);
        }
        return result;
    }
}
