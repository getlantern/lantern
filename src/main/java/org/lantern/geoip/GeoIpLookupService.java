package org.lantern.geoip;

import java.net.URI;
import java.net.InetSocketAddress;
import java.net.InetAddress;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.lang3.SystemUtils;
import org.lantern.util.HttpClientFactory;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.lantern.geoip.GeoData;
import org.lantern.state.Peer;

import com.google.inject.Singleton;

/**
 * Service for GeoLocating. Uses MaxMind's {@link LookupService} internally.
 */
@Singleton
public class GeoIpLookupService {
  private static final Logger LOG = LoggerFactory
    .getLogger(GeoIpLookupService.class);


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

    public void updateGeoData(final Peer peer, final URI fullJid,  
        final String address) {
      if (peer == null) {
        LOG.warn("No peer for {}", fullJid);
        return;
      }
      if (peer.hasGeoData()) {
        LOG.debug("Peer already had geo data: {}", peer);
        return;
      }
      final GeoData geo = getGeoData(address);
      peer.setCountry(geo.getCountrycode());
      peer.setLat(geo.getLatitude());
      peer.setLon(geo.getLongitude());
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
