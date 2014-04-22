package org.lantern.util;

import java.io.IOException;

import org.apache.http.client.HttpClient;
import org.lantern.Censored;
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

    @Inject
    public DefaultHttpClientFactory(final Censored censored) {
        this.censored = censored;
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
            return StaticHttpClientFactory.newProxiedClient();
        } else {
            return StaticHttpClientFactory.newDirectClient();
        }
    }

    @Override
    public HttpClient newDirectClient() {
        return StaticHttpClientFactory.newDirectClient();
    }

    @Override
    public HttpClient newProxiedClient() {
        return StaticHttpClientFactory.newProxiedClient();
    }
}
