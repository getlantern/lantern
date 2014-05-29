package org.lantern.geoip;

import java.net.InetAddress;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.lang3.SystemUtils;
import org.lantern.util.HttpClientFactory;

import org.lantern.geoip.GeoData;

import com.google.inject.Singleton;

/**
 * Service for GeoLocating. Uses MaxMind's {@link LookupService} internally.
 */
@Singleton
public class GeoIpLookupService {
    private final Map<InetAddress, GeoData> addressLookupCache =
            new ConcurrentHashMap<InetAddress, GeoData>();
    private final Map<String, GeoData> stringLookupCache =
            new ConcurrentHashMap<String, GeoData>();

    private HttpClientFactory httpClientFactory;

    public GeoIpLookupService(final HttpClientFactory httpClientFactory) {
      this.httpClientFactory = httpClientFactory;
    }

    public GeoData getGeoData(InetAddress ipAddress) {
        GeoData result = addressLookupCache.get(ipAddress);
        if (result == null) {
            result = GeoData.queryGeoServe(this.httpClientFactory, ipAddress.getHostAddress());
            addressLookupCache.put(ipAddress, result);
        }
        return result;
    }

    public GeoData getGeoData(String ipAddress) {
        GeoData result = stringLookupCache.get(ipAddress);
        if (result == null) {
            result = GeoData.queryGeoServe(this.httpClientFactory, ipAddress);
            stringLookupCache.put(ipAddress, result);
        }
        return result;
    }
}
