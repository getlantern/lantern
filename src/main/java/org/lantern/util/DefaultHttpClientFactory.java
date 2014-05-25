package org.lantern.util;

import java.io.IOException;

import org.apache.http.client.HttpClient;
import org.lantern.Censored;
import org.lantern.LanternTrustStore;
import org.lantern.LanternUtils;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class for handling HTTP client interaction.
 * 
 * TODO: We really need all of these methods to follow similar logic to 
 * OauthUtils and to try to connect directly. 
 */
@Singleton
public class DefaultHttpClientFactory implements HttpClientFactory {

    private final Censored censored;
    private final LanternTrustStore trustStore;

    @Inject
    public DefaultHttpClientFactory(final Censored censored, LanternTrustStore trustStore) {
        this.censored = censored;
        this.trustStore = trustStore;
    }

    /**
     * Returns a proxied client if we have access to a proxy in get mode.
     * 
     * @return The proxied {@link HttpClient} if available in get mode, 
     * otherwise an unproxied client.
     * @throws IOException If we could not obtain a proxied client.
     */
    @Override
    public HttpClient newClient() {
        if (this.censored.isCensored() || LanternUtils.isGet()) {
            return newProxiedClient();
        } else {
            return newDirectClient();
        }
    }

    @Override
    public HttpClient newDirectClient() {
        // Use a cumulative SSLContext that trusts the usual certs, plus
        // anything in LanternTrustStore, which allows our client to work with
        // the MITM'ing flashlight proxy.
        return StaticHttpClientFactory.newDirectClient(trustStore.getCumulativeSslContext());
    }

    @Override
    public HttpClient newProxiedClient() {
        // Use a cumulative SSLContext that trusts the usual certs, plus
        // anything in LanternTrustStore, which allows our client to work with
        // the MITM'ing flashlight proxy.
        return StaticHttpClientFactory.newProxiedClient(trustStore.getCumulativeSslContext());
    }
}
