package org.lantern;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.lantern.proxy.DefaultProxyTracker;
import org.lantern.proxy.FallbackProxy;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * TODO: Suppress the normal ways of discovering additional proxies for this test,
 * e.g. disable kaleidoscopic discovery of proxies and don't include any in s3config
 */
public class FallbackChecker implements Runnable {

    private static final int CHECK_SLEEP_TIME = 300000; // milliseconds
    private DefaultProxyTracker proxyTracker;
    private List<FallbackProxy> proxies = new ArrayList<FallbackProxy>();
    private static final String TEST_URL = "http://www.google.com/humans.txt";
    private static final Logger LOG = LoggerFactory
            .getLogger(FallbackChecker.class);

    public FallbackChecker(DefaultProxyTracker proxyTracker) {
        this.proxyTracker = proxyTracker;

        // TODO: get this info from controller
        FallbackProxy fp = new FallbackProxy();
        fp.setIp("107.170.61.149");
        fp.setAuth_token("UhjpnpnUBGqk9qopJ294ge98KsHTUtVF2DFjfNESp8mDxLtZcF3qJz2ysJ7EYzNW");
        fp.setCert("-----BEGIN CERTIFICATE-----\nMIIBcDCCAROgAwIBAgIEQeGHKjAMBggqhkjOPQQDAgUAMCwxDDAKBgNVBAoTA0V5ZTEcMBoGA1UE\nAxMTRmlyZWNyYWNrZXIgUHJpemluZzAeFw0xNDAyMDcwMTU4NDdaFw0xNTAyMDcwMTU4NDdaMCwx\nDDAKBgNVBAoTA0V5ZTEcMBoGA1UEAxMTRmlyZWNyYWNrZXIgUHJpemluZzBZMBMGByqGSM49AgEG\nCCqGSM49AwEHA0IABC4JpO0M0102gNaViNxP+lJ19GUxcuBvMNehxUQvTgvxMGSu9QFTrio+p5OC\nstSskTENlQdQ0ERjrPdULC1/i1+jITAfMB0GA1UdDgQWBBT46eI0Pe5/fNVYIc0YHtJ6U2WBsTAM\nBggqhkjOPQQDAgUAA0kAMEYCIQCjutFwX4O4GgCIr9OO48ayxOL8mq7tcrLA/OeSkNAVdQIhAKjN\n9hi36kHfKVmqQ6469x5odopW6DBTGAMbF2CDz/+h\n-----END CERTIFICATE-----\n");
        fp.setProtocol("tcp");
        fp.setPort(443);
        proxies.add(fp);
    }

    @Override
    public void run() {
        try {
            // sleep a bit to make sure everything's ready before we start
            Thread.sleep(20000);
            for (;;) {
                proxyTracker.clear();
                for (FallbackProxy p : proxies) {
                    proxyTracker.addSingleFallbackProxy(p);
                    String msg = "testing proxying through fallback: "+p.getWanHost()+"... ";
                    if (canProxyThroughCurrentFallback()) {
                        LOG.info(msg+"success");
                    } else {
                        LOG.warn(msg+"fail");
                    }
                    proxyTracker.clear();
                }
                Thread.sleep(CHECK_SLEEP_TIME);
            }
        } catch (InterruptedException e) {
        }
    }
    
    private boolean canProxyThroughCurrentFallback() {
        final HttpClient client = HttpClientFactory.newProxiedClient();
        final HttpGet get = new HttpGet(TEST_URL);
        InputStream is = null;
        try {
            final HttpResponse res = client.execute(get);
            is = res.getEntity().getContent();
            final String content = IOUtils.toString(is);
            return StringUtils.startsWith(content, "Google is built by");
        } catch (final IOException e) {
            return false;
        } finally {
            IOUtils.closeQuietly(is);
            get.reset();
        }
    }
}
