package org.lantern;

import java.io.IOException;
import java.net.URI;

import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.utils.URIBuilder;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class YqlTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    @Test
    public void test() throws Exception {
        //final String endpoint = "http://query.yahooapis.com/v1/public/yql";
        //final String query = "SELECT * from geo.places WHERE text='SFO'";
        //final String query = "select Latitude,Longitude from ip.location where ip = '76.170.128.133'";
        /*
        final String query = "USE 'http://www.datatables.org/iplocation/ip.location.xml' " +
            "AS ip.location; select centroid from geo.places where woeid in " +
            "( select place.woeid from flickr.places where (lat,lon) in " +
            "( select Latitude,Longitude from ip.location where ip = '76.170.128.133' " +
            "and key = 'a6a2704c6ebf0ee3a0c55d694431686c0b6944afd5b648627650ea1424365abb') " +
            "and api_key = 'd67bc572b8b129a7264d1780fd9ed084')";
            */
        
        final String query = "USE 'http://www.datatables.org/iplocation/ip.location.xml' " +
            "AS ip.location; select CountryCode, Latitude,Longitude from ip.location where ip = '76.170.128.133' " +
            "and key = 'a6a2704c6ebf0ee3a0c55d694431686c0b6944afd5b648627650ea1424365abb'";

        /*
        final String query = "USE 'http://www.datatables.org/iplocation/ip.location.xml' " +
            "AS ip.location; select * from ip.location where ip = '76.170.128.133' " +
            "and key = 'a6a2704c6ebf0ee3a0c55d694431686c0b6944afd5b648627650ea1424365abb'";
        */
        
        // The problem with the below is it's not a production site.
        //final String query = "USE 'http://www.datatables.org/misc/geoip/pidgets.geoip.xml' AS pidgets.geoip; select * from pidgets.geoip where ip='128.100.100.128'";
        
        //final String query = "select * from geo.places where woeid in ( select place.woeid from flickr.places where (lat,lon) in ( select latitude,longitude from pidgets.geoip where ip = '123.23.23.33') )";
        final URIBuilder builder = new URIBuilder();
        builder.setScheme("https").setHost("query.yahooapis.com").setPath("/v1/public/yql")
            .setParameter("q", query).setParameter("format", "json");
        //builder.setScheme("http").setHost("api.ipinfodb.com").setPath("/v3/ip-city/")
        //    .setParameter("ip", "76.170.128.133").setParameter("key", "a6a2704c6ebf0ee3a0c55d694431686c0b6944afd5b648627650ea1424365abb");
        
        
        final URI uri = builder.build();
        final DefaultHttpClient client = new DefaultHttpClient();
        final HttpGet get = new HttpGet(uri);
        
        try {
            final HttpResponse response = client.execute(get);

            log.debug("Got response status: {}", response.getStatusLine());
            final HttpEntity entity = response.getEntity();
            final String body = IOUtils.toString(entity.getContent());
            System.out.println(body);
            EntityUtils.consume(entity);
            log.debug("GOT RESPONSE BODY FOR EMAIL:\n"+body);
        } catch (final IOException e) {
            log.warn("Could not connect to Google?", e);
        } finally {
            get.releaseConnection();
        }
    }

}
