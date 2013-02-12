package org.lantern;

import static org.junit.Assert.assertTrue;

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
import org.apache.http.params.CoreConnectionPNames;
import org.apache.http.util.EntityUtils;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * End-to-end proxying test to make sure we're able to proxy access to
 * different sites.
 */
public class LanternProxyingTest {

    private final Logger log = LoggerFactory.getLogger(getClass());

    @Test
    public void testWithHttpClient() throws Exception {
        final Launcher launcher =
            new Launcher(new String[]{"--disable-ui", "--force-get",
            "--refresh-tok", TestUtils.getRefreshToken(),
            "--access-tok", TestUtils.getAccessToken()});
        launcher.run();

        //Thread.sleep(8000);
        LanternUtils.waitForServer(LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);
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
        final HttpClient client = new DefaultHttpClient();
        int good = 0;
        for (final String site : censored) {
            log.warn("TESTING SITE: {}", site);
            good += testWhitelistedSite(site, client,
                LanternConstants.LANTERN_LOCALHOST_HTTP_PORT) ? 1 : 0;
        }
        //allow at most five failures
        assertTrue ("Too many failures", good >= censored.length - 5);
        //log.info("Stopping proxy");
        //proxy.stop();
        //Launcher.stop();
    }

    private boolean testWhitelistedSite(final String url, final HttpClient client,
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

        client.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT,
            3000);
        // Timeout when server does not send data.
        client.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 60000);
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
        if (200 !=  response.getStatusLine().getStatusCode()) {
            return false;
        }

        log.debug("Consuming entity");
        final HttpEntity entity = response.getEntity();
        final String raw = IOUtils.toString(entity.getContent());
        //log.debug("Raw response: "+raw);

        // The response body can actually be pretty small -- consider
        // responses like
        // <meta http-equiv="refresh" content="0;url=index.html">
        if (raw.length() <= 40) {
            return false;
        }
        EntityUtils.consume(entity);
        return true;
    }
}
