package org.lantern.geoip;

import java.io.InputStream;
import java.net.InetAddress;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.io.IOUtils;
import org.apache.http.HttpResponse;
import org.lantern.JsonUtils;
import org.lantern.S3Config;
import org.lantern.http.HttpUtils;
import org.lantern.util.HostSpoofedHTTPGet;
import org.lantern.util.HostSpoofedHTTPGet.ResponseHandler;
import org.lantern.util.StaticHttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Singleton;

/**
 * Service for GeoLocating. Uses the web service at geo.getiantem.org.
 */
@Singleton
public class GeoIpLookupService {

    private static final Logger LOG = LoggerFactory
            .getLogger(GeoIpLookupService.class);

    private final Map<String, GeoData> cache =
            new ConcurrentHashMap<String, GeoData>();

    private static final String REAL_GEO_HOST = "geo.getiantem.org";

    public GeoData getGeoData(final InetAddress ipAddress) {
        return getGeoData(ipAddress.getHostAddress());
    }

    public GeoData getGeoData(String ipAddress) {
        GeoData result = cache.get(ipAddress);
        if (result == null) {
            result = this.queryGeoServe(ipAddress);
            cache.put(ipAddress, result);
        }
        return result;
    }

    public static <T> T httpLookup(String ipAddress, ResponseHandler<T> handler) {
        return httpLookup(ipAddress, handler, S3Config.getMasqueradeHost());
    }
    
    public static <T> T httpLookup(String ipAddress, ResponseHandler<T> handler,
            final String masqueradeHost) {
        String url = "/lookup";
        if (ipAddress != null) {
            url += "/" + ipAddress;
        }
        return new HostSpoofedHTTPGet(
                StaticHttpClientFactory.newDirectClient(),
                REAL_GEO_HOST,
                masqueradeHost).get(url, handler);
    }

    private GeoData queryGeoServe(final String ipAddress) {
        return httpLookup(ipAddress, new ResponseHandler<GeoData>() {
            @Override
            public GeoData onResponse(HttpResponse response) throws Exception {
                final int status = response.getStatusLine().getStatusCode();
                if (status != 200) {
                    LOG.error(
                            "Error on proxied request. No proxies working? {}, {}",
                            response.getStatusLine(),
                            HttpUtils.httpHeaders(response));
                    return new GeoData();
                }
                InputStream is = response.getEntity().getContent();
                try {
                    final String geoStr = IOUtils.toString(is);
                    LOG.debug("Geo lookup response " + geoStr);
                    return JsonUtils.OBJECT_MAPPER.readValue(geoStr,
                            GeoData.class);
                } catch (Exception e) {
                    LOG.warn("Error parsing JSON from geo lookup " +
                            e.getMessage(), e);
                    return new GeoData();
                } finally {
                    IOUtils.closeQuietly(is);
                }
            }

            @Override
            public GeoData onException(Exception e) {
                LOG.warn("Error calling geo lookup service " +
                        e.getMessage(), e);
                return new GeoData();
            }
        });
    }
}
