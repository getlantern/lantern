package org.lantern.util;

import java.util.Arrays;
import java.util.List;

import org.apache.commons.lang.math.RandomUtils;
import org.apache.http.Header;
import org.apache.http.HttpHost;
import org.apache.http.client.HttpClient;
import org.apache.http.client.config.RequestConfig;
import org.apache.http.impl.client.DefaultHttpRequestRetryHandler;
import org.apache.http.impl.client.HttpClientBuilder;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.message.BasicHeader;
import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for handling HTTP client interaction.
 */
public class StaticHttpClientFactory {

    private static final Logger log = 
            LoggerFactory.getLogger(StaticHttpClientFactory.class);
    
    public static HttpClient newDirectClient() {
        log.debug("Returning direct client");
        return newClient(null);
    }

    public static HttpClient newProxiedClient() {
        log.debug("Returning proxied client");
        final HttpHost proxy = new HttpHost("127.0.0.1",
                LanternConstants.LANTERN_LOCALHOST_HTTP_PORT,
                "http");
        return newClient(proxy);
    }

    public static HttpClient newClient(final HttpHost proxy) {
        // Always add a random length to be less identifiable over the wire.
        final Header header = new BasicHeader("Lan-Rand", randomLengthVal());
        final List<Header> headers = Arrays.asList(header);
        
        final RequestConfig defaultRequestConfig = RequestConfig.custom().
                setStaleConnectionCheckEnabled(true).
                setConnectTimeout(50000).
                setSocketTimeout(120000).
                build();
        
        final HttpClientBuilder builder = 
                HttpClients.custom().setDefaultHeaders(headers).
                setRetryHandler(new DefaultHttpRequestRetryHandler(3,true)).
                setDefaultRequestConfig(defaultRequestConfig);
        
        if (proxy != null) {
            builder.setProxy(proxy);
            LanternUtils.waitForServer(proxy.getHostName(), proxy.getPort(), 10000);
        }
        
        final HttpClient client = builder.build();
        return client;
    }
    
    /**
     * Creates a random length header value to avoid same length requests.
     * Note these should always be sent over an encrypted connection, so the
     * actual characters don't matter.
     * 
     * @return A random length string.
     */
    private static String randomLengthVal() {
        final int length = RandomUtils.nextInt() % 60;
        final StringBuilder sb = new StringBuilder();
        for (int i = 0; i < length; i++) {
            sb.append(i);
        }
        return sb.toString();
    }
}
