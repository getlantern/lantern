package org.lantern;

import static org.junit.Assert.*;

import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashSet;
import java.util.concurrent.Callable;

import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpHeaders;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.params.CoreConnectionPNames;
import org.apache.http.util.EntityUtils;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * End-to-end proxying test to make sure we're able to proxy access to different
 * sites.
 */
public class LanternProxyingTest {

    private final Logger log = LoggerFactory.getLogger(getClass());

    @Test
    public void testWithHttpClient() throws Exception {
        final Collection<String> censored = Arrays.asList(// "exceptional.io");
                "www.getlantern.org",
                "github.com",
                "facebook.com",
                //"appledaily.com.tw",
                "orkut.com",
                "voanews.com",
                "balatarin.com",
                "igfw.net"
                );

        TestingUtils.doWithGetModeProxy(new Callable<Void>() {
            @Override
            public Void call() throws Exception {
                final HttpClient client = new DefaultHttpClient();

                final Collection<String> successful = new HashSet<String>();
                final Collection<String> failed = new HashSet<String>();
                for (final String site : censored) {
                    log.debug("TESTING SITE: {}", site);
                    final boolean succeeded = testWhitelistedSite(site, client,
                            LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);
                    if (succeeded) {
                        successful.add(site);
                    } else {
                        failed.add(site);
                    }
                }
                
                assertTrue("There were too many site failures: " + failed ,
                       successful.size() > censored.size()/2);
                return null;
            }
        });
    }

    private boolean testWhitelistedSite(final String url,
            final HttpClient client,
            final int proxyPort) throws Exception {
        final HttpGet get = new HttpGet("http://" + url);

        try {

            // Some sites require more standard headers to be present.
            get.setHeader(
                    "User-Agent",
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:15.0) Gecko/20100101 Firefox/15.0");
            get.setHeader("Accept",
                    "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
            get.setHeader("Accept-Language", "en-us,en;q=0.5");
            //get.setHeader("Accept-Encoding", "gzip, deflate");

            client.getParams().setParameter(
                    CoreConnectionPNames.CONNECTION_TIMEOUT,
                    6000);
            // Timeout when server does not send data.
            client.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT,
                    30000);
            client.getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY,
                    new HttpHost("localhost", proxyPort));
            final HttpResponse response;
            try {
                response = client.execute(get);
            } catch (final ClientProtocolException e) {
                log.warn("Protocol error connecting to " + url, e);
                throw e;
            } catch (final IOException e) {
                log.warn("IO error connecting to " + url, e);
                return false;
            }

            if (200 != response.getStatusLine().getStatusCode()) {
                return false;
            }
            log.debug("STATUS: {}", response.getStatusLine());
            log.debug("RESPONSE HEADERS: {}", Arrays.asList(response.getAllHeaders()));
            log.debug("Consuming entity of length: {}", response.getFirstHeader(HttpHeaders.CONTENT_LENGTH));
            log.debug("Encoding: {}", response.getFirstHeader(HttpHeaders.TRANSFER_ENCODING));
            final HttpEntity entity = response.getEntity();
            final InputStream content = entity.getContent();
            
            final String raw = IOUtils.toString(content);
            // log.debug("Raw response: "+raw);

            // The response body can actually be pretty small -- consider
            // responses like
            // <meta http-equiv="refresh" content="0;url=index.html">
            if (raw.length() <= 40) {
                return false;
            }
            EntityUtils.consumeQuietly(entity);
        } catch (Exception e) {
            e.printStackTrace();
            fail(String.format("Exception on testing %1$s: %2$s", url,
                    e.getMessage()));
        } finally {
            get.reset();
        }
        return true;
    }
}