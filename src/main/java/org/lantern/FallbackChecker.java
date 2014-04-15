package org.lantern;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.http.HttpResponse;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.codehaus.jackson.type.TypeReference;
import org.lantern.proxy.DefaultProxyTracker;
import org.lantern.proxy.FallbackProxy;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Optional;

/**
 * TODO: Suppress the normal ways of discovering additional proxies for this test,
 * e.g. disable kaleidoscopic discovery of proxies and don't include any in s3config
 */
public class FallbackChecker implements Runnable {

    private static final int CHECK_SLEEP_TIME = 300000; // milliseconds
    private DefaultProxyTracker proxyTracker;
    private List<FallbackProxy> fallbacks = new ArrayList<FallbackProxy>();
    private static final String TEST_URL = "http://www.google.com/humans.txt";
    private static final String TEST_RESULT_PREFIX = "Google is built by";
    private static final Logger LOG = LoggerFactory
            .getLogger(FallbackChecker.class);

    public FallbackChecker(DefaultProxyTracker proxyTracker, String configFolderPath) {
        this.proxyTracker = proxyTracker;
        populateFallbacks(configFolderPath);
    }

    private void populateFallbacks(String configFolderPath) {
        final File file = new File(configFolderPath);
        if (!(file.exists() && file.canRead())) {
            throw new IllegalArgumentException("Cannot read file: " + configFolderPath);
        }
        Optional<String> url = S3ConfigFetcher.readUrlFromFile(file);
        if (!url.isPresent()) {
            throw new RuntimeException("url not present");
        }
        Optional<String> config = S3ConfigFetcher.fetchRemoteConfig(url.get());
        if (!config.isPresent()) {
            throw new RuntimeException("config not present");
        }
        try {
            fallbacks = JsonUtils.OBJECT_MAPPER.readValue(config.get(), new TypeReference<List<FallbackProxy>>() {});
        } catch (final Exception e) {
            throw new RuntimeException("Could not parse json:\n" + config.get() + "\n" + e);
        }
    }

    @Override
    public void run() {
        try {
            // sleep a bit to make sure everything's ready before we start
            Thread.sleep(20000);
            for (;;) {
                proxyTracker.clear();
                for (FallbackProxy fb : fallbacks) {
                    proxyTracker.addSingleFallbackProxy(fb);
                    final String addr = fb.getWanHost();
                    LOG.info("testing proxying through fallback: " + addr);
                    boolean working = false;
                    try {
                        working = canProxyThroughCurrentFallback();
                    } catch (Exception e) {
                        LOG.warn("proxying through fallback " + addr + " failed:\n" + e.toString());
                    }
                    if (working) {
                        LOG.info("proxying through fallback " + addr + " succeeded");
                    }
                    proxyTracker.clear();
                }
                Thread.sleep(CHECK_SLEEP_TIME);
            }
        } catch (InterruptedException e) {
        }
    }
    
    private boolean canProxyThroughCurrentFallback() throws Exception {
        final HttpClient client = HttpClientFactory.newProxiedClient();
        final HttpGet get = new HttpGet(TEST_URL);
        InputStream is = null;
        try {
            final HttpResponse res = client.execute(get);
            is = res.getEntity().getContent();
            final String content = IOUtils.toString(is);
            if (StringUtils.startsWith(content, TEST_RESULT_PREFIX)) {
                return true;
            } else {
                throw new Exception(
                    "response for " + TEST_URL + " did not match expectation\n" +
                    "expected: " + TEST_RESULT_PREFIX + "\n" +
                    "observed: " + content);
            }
        } finally {
            IOUtils.closeQuietly(is);
            get.reset();
        }
    }
}
