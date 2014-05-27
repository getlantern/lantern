package org.lantern.geoip;


import java.io.IOException;

import org.apache.commons.io.FileUtils;
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

import org.codehaus.jackson.JsonParseException;
import org.codehaus.jackson.map.JsonMappingException;
import org.codehaus.jackson.map.ObjectMapper;
import org.codehaus.jackson.annotate.JsonAutoDetect.Visibility;
import org.codehaus.jackson.annotate.JsonMethod;
import org.codehaus.jackson.map.DeserializationConfig;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
 

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

class Country {
  private String IsoCode;

  public String getIsoCode() {
    return IsoCode;
  }
}

public class GeoData {
  private static final Logger log = LoggerFactory.getLogger(GeoData.class);

  private static final String LOOKUP_URL = "http://go-geoserve.herokuapp.com/lookup/";
  private Country Country;
  private Location Location;

  public GeoData() {

  }

  public double getLatitude() {
    return Location.getLatitude();
  }

  public double getLongitude() {
    return Location.getLongitude();
  }

  public String getCountrycode() {
    return Country.getIsoCode();
  }

  public static GeoData fromJson(String json) throws JsonMappingException, IOException {
    ObjectMapper mapper = new ObjectMapper().setVisibility(JsonMethod.FIELD, Visibility.ANY);
    mapper.configure(DeserializationConfig.Feature.FAIL_ON_UNKNOWN_PROPERTIES, false);
    return mapper.readValue(json, GeoData.class);
  }


  public static GeoData queryGeoServe(String ipAddress) {
    final HttpClient client = new DefaultHttpClient();
    final HttpGet get = new HttpGet(LOOKUP_URL + ipAddress);
    try {
      final HttpResponse response = client.execute(get);
      final int status = response.getStatusLine().getStatusCode();
      final HttpEntity entity = response.getEntity();
      final String json = IOUtils.toString(entity.getContent());
      return fromJson(json);
    } catch (ClientProtocolException e) {
      // TODO Auto-generated catch block
      e.printStackTrace();
    } catch (JsonMappingException e) {
      e.printStackTrace();
    } catch (IOException e) {
      // TODO Auto-generated catch block
      e.printStackTrace();
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
