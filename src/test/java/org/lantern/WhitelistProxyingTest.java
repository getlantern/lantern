package org.lantern;

import static org.junit.Assert.assertEquals;

import java.io.IOException;

import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class WhitelistProxyingTest {


    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Test
    public void testWithHttpClient() throws Exception {
        Launcher.main(new String[]{"--disable-ui", "--force-get", 
            "--user", "lanternftw@gmail.com", "--pass", "fjdl520208FD31"});
        
        Thread.sleep(20000);
        /*
        final int proxyPort = 10200;
        final HttpProxyServer proxy = 
            new DefaultHttpProxyServer(proxyPort, new HttpRequestFilter() {
            @Override
            public void filter(final HttpRequest httpRequest) {
                System.out.println("Request went through proxy");
            }
        });
    
        proxy.start();
        */
        
        final String[] censored = Whitelist.SITES;
        //final String[] censored = new String[] {"irangreenvoice.com/"};
        final HttpClient client = new DefaultHttpClient();
        for (final String site : censored) {
            log.warn("TESTING SITE: {}", site);
            testWhitelistedSite(site, client, 8787);
        }
        
        //log.info("Stopping proxy");
        //proxy.stop();
    }
    
    private void testWhitelistedSite(final String url, final HttpClient client, 
        final int proxyPort) throws Exception {
    
        final HttpGet get = new HttpGet("http://"+url);
        //get.setHeader(HttpHeaders.Names.CONTENT_RANGE, "Range: bytes=0-1999999");
        //get.setHeader(HttpHeaders.Names.HOST, "rlanternz.appspot.com");
    //    get.setHeader("Lantern-Version", "lantern_version_tok");
        
        // Some sites require more standard headers to be present.
        get.setHeader("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:15.0) Gecko/20100101 Firefox/15.0");
        get.setHeader("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
        get.setHeader("Accept-Language", "en-us,en;q=0.5");
        get.setHeader("Accept-Encoding", "gzip, deflate");
    //    get.setHeader("Proxy-Connection", "keep-alive");
    //    get.setHeader("Host", "rlanternz.appspot.com");
    //    get.setHeader("Lantern-Version", "lantern_version_tok");
    //    get.setHeader("Range", "bytes=0-1999999");
        
        /*
        HttpResponse response = client.execute(get);
        
        final Header[] headers = response.getAllHeaders();
        for (final Header h : headers) {
            System.out.println(h.getName() + ": "+h.getValue());
        }
        //assertEquals(200, response.getStatusLine().getStatusCode());
        EntityUtils.consume(response.getEntity());
        */
        
        client.getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY, 
            new HttpHost("localhost", proxyPort));
        final HttpResponse response;
        try {
            response = client.execute(get);
        } catch (final ClientProtocolException e) {
            log.warn("Protocol error connecting to "+url, e);
            throw e;
        } catch (final IOException e) {
            log.warn("IO error connecting to "+url, e);
            throw e;
        }
        assertEquals("Did not get 200 response for site: "+url, 200, 
                response.getStatusLine().getStatusCode());
        
        log.info("Consuming entity");
        final HttpEntity entity = response.getEntity();
        final String raw = IOUtils.toString(entity.getContent());
        log.info("Raw response: "+raw);
        EntityUtils.consume(entity);
    }
}
