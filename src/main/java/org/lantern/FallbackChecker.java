package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.params.CoreConnectionPNames;
import org.codehaus.jackson.type.TypeReference;
import org.lantern.proxy.FallbackProxy;
import org.lantern.proxy.ProxyTracker;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class FallbackChecker implements Runnable {

    private ProxyTracker proxyTracker;
    private List<FallbackProxy> fallbacks = new ArrayList<FallbackProxy>();
    private static final String ALERTCMD_PATH = "/home/lantern/alert_fallbacks_failing_to_proxy.py";
    private static final String TEST_URL = "http://www.google.com/humans.txt";
    private static final String TEST_RESULT_PREFIX = "Google is built by";
    private static final Logger LOG = LoggerFactory
            .getLogger(FallbackChecker.class);
    private final HttpClientFactory httpClientFactory;

    public FallbackChecker(final ProxyTracker proxyTracker, 
            String configFolderPath, final HttpClientFactory httpClientFactory) {
        this.proxyTracker = proxyTracker;
        this.httpClientFactory = httpClientFactory;
        populateFallbacks(configFolderPath);
    }

    private void populateFallbacks(String configFolderPath) {
        final File file = new File(configFolderPath);
        if (!(file.exists() && file.canRead())) {
            throw new IllegalArgumentException("Cannot read file: " + configFolderPath);
        }
        
        InputStream fis = null;
        final String folder;
        try {
            fis = new FileInputStream(file);
            folder = IOUtils.toString(fis);
        } catch (final IOException e) {
            throw new RuntimeException("Could not read folder", e);
        } finally {
            IOUtils.closeQuietly(fis);
        }
        final HttpClient client = this.httpClientFactory.newDirectClient();
        client.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 10000);
        client.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 10000);
        final HttpGet get = new HttpGet(S3ConfigFetcher.urlFromFolder(folder));
        
        final String proxies;
        InputStream is = null;
        try {
            final HttpResponse res = client.execute(get);
            is = res.getEntity().getContent();
            proxies = IOUtils.toString(is);
        } catch (final IOException e) {
            IOUtils.closeQuietly(is);
            get.reset();
            throw new RuntimeException("Could not get config", e);
        }
        try {
            fallbacks = JsonUtils.OBJECT_MAPPER.readValue(proxies, new TypeReference<List<FallbackProxy>>() {});
        } catch (final Exception e) {
            throw new RuntimeException("Could not parse json:\n" + proxies + "\n" + e);
        }
    }

    @Override
    public void run() {
        List<String> failed = new ArrayList<String>();
        try {
            // sleep a bit to make sure everything's ready before we start
            Thread.sleep(20000);

            int nsucceeded = 0;
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
                    failed.add(addr);
                }
                if (working) {
                    LOG.info("proxying through fallback " + addr + " succeeded");
                    ++nsucceeded;
                }
                proxyTracker.clear();
            }
            int nfailed = failed.size();
            LOG.info(String.format("Finished checking fallbacks:\n" +
                                   "nsucceeded: %d\n" +
                                   "nfailed:    %d\n" +
                                   "total:      %d",
                                   nsucceeded, nfailed, nsucceeded + nfailed));
            if (nfailed > 0) {
                failed.add(0, ALERTCMD_PATH);
                new ProcessBuilder(failed).start();
            }
            System.exit(nfailed);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private boolean canProxyThroughCurrentFallback() throws Exception {
        final HttpClient client = this.httpClientFactory.newProxiedClient();
        client.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 10000);
        client.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 10000);
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
