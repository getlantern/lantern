package org.lantern.geoip;


import java.io.IOException;
import java.io.InputStream;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.SystemUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.commons.httpclient.HttpException;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.client.DefaultHttpRequestRetryHandler;

import org.lantern.JsonUtils;
import org.apache.commons.io.IOUtils;
import org.codehaus.jackson.map.ObjectMapper;

import org.lantern.util.HttpClientFactory;
import org.lantern.http.HttpUtils;


import org.codehaus.jackson.annotate.JsonAutoDetect;
import org.codehaus.jackson.annotate.JsonMethod;
import org.codehaus.jackson.map.DeserializationConfig;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@JsonAutoDetect(fieldVisibility=JsonAutoDetect.Visibility.ANY)
class Country {
  private String IsoCode;

  public String getIsoCode() {
    return IsoCode;
  }
}

@JsonAutoDetect(fieldVisibility=JsonAutoDetect.Visibility.ANY)
class Location {
  private double Latitude;
  private double Longitude;

  public double getLatitude() {
    return Latitude;
  }

  public double getLongitude() {
    return Longitude;
  }
}

@JsonAutoDetect(fieldVisibility=JsonAutoDetect.Visibility.ANY)
public class GeoData {

  private static final Logger LOGGER = LoggerFactory.getLogger(GeoData.class);

  private static final String LOOKUP_URL = 
                        "http://go-geoserve.herokuapp.com/lookup/";

  private Country Country;
  private Location Location;

  public double getLatitude() {
    return Location.getLatitude();
  }

  public double getLongitude() {
    return Location.getLongitude();
  }

  public String getCountrycode() {
    return Country.getIsoCode();
  }
   
  public static GeoData queryGeoServe(final HttpClientFactory httpClientFactory, String ipAddress) {
    final HttpClient proxied = httpClientFactory.newProxiedClient();
    final HttpGet get = new HttpGet(LOOKUP_URL + ipAddress);
    InputStream is = null;
    try {
      final HttpResponse response = proxied.execute(get);
      final int status = response.getStatusLine().getStatusCode();
      if (status != 200) {
        LOGGER.error("Error on proxied request. No proxies working? {}, {}",
          response.getStatusLine(), HttpUtils.httpHeaders(response));
        throw new HttpException("Error communicating with geolocation server");
      }

      is = response.getEntity().getContent();
      final String geoStr = IOUtils.toString(is);
      LOGGER.debug("Geo lookup response " + geoStr);

      return JsonUtils.OBJECT_MAPPER.readValue(geoStr, GeoData.class);
    } catch (ClientProtocolException e) {
      LOGGER.warn("Error connecting to geo lookup service " + 
          e.getMessage(), e);
    } catch (IOException e) {
      LOGGER.warn("Error parsing JSON from geo lookup " + 
          e.getMessage(), e);
    }
    finally {
      IOUtils.closeQuietly(is);
      get.reset();
    }
    return null;
  }

  @Override
    public String toString() {
      return "GeoData [countryCode=" + getCountrycode() + ", latitude="
        + getLatitude()
        + ", longitude=" + getLongitude() + "]";
    }
}
