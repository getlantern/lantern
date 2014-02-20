package org.lantern.util;

import java.io.IOException;

import org.apache.http.HttpHost;
import org.apache.http.client.HttpClient;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.client.DefaultHttpRequestRetryHandler;
import org.apache.http.params.CoreConnectionPNames;
import org.lantern.Censored;
import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class for handling HTTP client interaction.
 * 
 * TODO: We really need all of these methods to follow similar logic to 
 * OauthUtils and to try to connect directly. 
 */
@Singleton
public class HttpClientFactory {

    private static final Logger log = LoggerFactory.getLogger(HttpClientFactory.class);
    private final Censored censored;

    @Inject
    public HttpClientFactory(final Censored censored) {
        this.censored = censored;
    }

    /**
     * Returns a proxied client if we have access to a proxy in get mode.
     * 
     * @return The proxied {@link HttpClient} if available in get mode, 
     * otherwise an unproxied client.
     * @throws IOException If we could not obtain a proxied client.
     */
    public HttpClient newClient() {
        if (this.censored.isCensored()) {
            return newProxiedClient();
        } else {
            return newDirectClient();
        }
    }
    
    public static HttpClient newDirectClient() {
        log.debug("Returning direct client");
        return newClient(null);
    }

    public static HttpClient newProxiedClient() {
        log.debug("Returning proxied client");
        HttpHost proxy = new HttpHost("127.0.0.1",
                LanternConstants.LANTERN_LOCALHOST_HTTP_PORT,
                "http");
        return newClient(proxy);
    }

    public static HttpClient newClient(final HttpHost proxy) {
        final DefaultHttpClient client = new DefaultHttpClient();
        configureDefaults(client);
        if (proxy != null) {
            client.getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY, proxy);
            LanternUtils.waitForServer(proxy.getHostName(), proxy.getPort(), 10000);
        }
        return client;
    }
    
    private static void configureDefaults(final DefaultHttpClient httpClient) {
        log.debug("Configuring defaults...");
        httpClient.setHttpRequestRetryHandler(new DefaultHttpRequestRetryHandler(2,true));
        httpClient.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 50000);
        httpClient.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 120000);
    }
}
