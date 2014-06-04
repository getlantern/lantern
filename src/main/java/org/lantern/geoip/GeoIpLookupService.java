package org.lantern.geoip;

import java.net.URI;
import java.net.InetSocketAddress;
import java.net.InetAddress;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.lantern.util.HttpClientFactory;
import org.lantern.http.HttpUtils;
import java.io.IOException;
import java.io.InputStream;


import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.SystemUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.client.DefaultHttpRequestRetryHandler;
import org.lantern.JsonUtils;
import org.apache.commons.io.IOUtils;
import org.codehaus.jackson.map.ObjectMapper;

import org.lantern.geoip.GeoData;

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

    private static final String geoServeUrl = "http://geo.getiantem.org/lookup/";

    private HttpClientFactory httpClientFactory;
   
    public GeoIpLookupService(final HttpClientFactory httpClientFactory) {
        this.httpClientFactory = httpClientFactory;
    }

    public GeoData getGeoData(InetAddress ipAddress) {
        GeoData result = addressLookupCache.get(ipAddress);
        if (result == null) {
            result = this.queryGeoServe(ipAddress.getHostAddress());
            addressLookupCache.put(ipAddress, result);
        }
        return result;
    }

    public GeoData queryGeoServe(String ipAddress) {
        final HttpClient proxied = this.httpClientFactory.newProxiedClient();
        final HttpGet get = new HttpGet(geoServeUrl + ipAddress);
        InputStream is = null;
        try {
            final HttpResponse response = proxied.execute(get);
            final int status = response.getStatusLine().getStatusCode();
            if (status != 200) {
                LOG.error("Error on proxied request. No proxies working? {}, {}",
                        response.getStatusLine(), HttpUtils.httpHeaders(response));
                return null;
            }
            is = response.getEntity().getContent();
            final String geoStr = IOUtils.toString(is);
            LOG.debug("Geo lookup response " + geoStr);
            return JsonUtils.OBJECT_MAPPER.readValue(geoStr, GeoData.class);
        } catch (ClientProtocolException e) {
            LOG.warn("Error connecting to geo lookup service " + 
                    e.getMessage(), e);
        } catch (IOException e) {
            LOG.warn("Error parsing JSON from geo lookup " + 
                    e.getMessage(), e);
        }
        finally {
            IOUtils.closeQuietly(is);
            get.reset();
        }
        return null;
    }

    public GeoData getGeoData(String ipAddress) {
        GeoData result = stringLookupCache.get(ipAddress);
        if (result == null) {
            result = this.queryGeoServe(ipAddress);
            stringLookupCache.put(ipAddress, result);
        }
        return result;
    }
}
