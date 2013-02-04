package org.lantern;

import static org.junit.Assert.assertTrue;

import java.net.URI;

import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.utils.URIBuilder;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;
import org.junit.Test;
import org.lantern.util.LanternHttpClient;

public class LanternHttpClientTest {

    @Test
    public void testHttpClient() throws Exception {
        final DefaultHttpClient client = new LanternHttpClient();
        
        final String query = 
            "USE 'http://www.datatables.org/iplocation/ip.location.xml' " +
            "AS ip.location; select CountryCode, Latitude,Longitude from " +
            "ip.location where ip = '86.170.128.133' and key = " +
            "'a6a2704c6ebf0ee3a0c55d694431686c0b6944afd5b648627650ea1424365abb'";

        final URIBuilder builder = new URIBuilder();
        builder.setScheme("https").setHost("query.yahooapis.com").setPath(
            "/v1/public/yql").setParameter("q", query).setParameter(
                "format", "json");
        
        final HttpGet get = new HttpGet();
        final URI uri = builder.build();
        get.setURI(uri);
        final HttpResponse response = client.execute(get);
        final HttpEntity entity = response.getEntity();
        final String body = 
            IOUtils.toString(entity.getContent()).toLowerCase();
        EntityUtils.consume(entity);
        
        assertTrue("Unexpected body: "+body, !body.contains("latitude"));

    }

}
