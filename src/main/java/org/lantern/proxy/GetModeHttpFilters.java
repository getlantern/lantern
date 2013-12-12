package org.lantern.proxy;

import io.netty.handler.codec.http.HttpObject;
import io.netty.handler.codec.http.HttpRequest;
import io.netty.handler.codec.http.HttpResponse;

import org.littleshoot.proxy.HttpFiltersAdapter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Filters used when proxying in Get mode.
 */
public class GetModeHttpFilters extends HttpFiltersAdapter {

    public static final String X_LANTERN_AUTH_TOKEN = "X-LANTERN-AUTH-TOKEN";

    private static final Logger LOG = LoggerFactory
            .getLogger(GetModeHttpFilters.class);

    private final String lanternAuthToken;

    public GetModeHttpFilters(HttpRequest originalRequest, String lanternAuthToken) {
        super(originalRequest);
        this.lanternAuthToken = lanternAuthToken;
    }

    /**
     * Add Lantern auth token to every request.
     */
    @Override
    public HttpResponse requestPre(HttpObject httpObject) {
        if (httpObject instanceof HttpRequest) {
            HttpRequest httpRequest = (HttpRequest) httpObject;
            httpRequest.headers().add(X_LANTERN_AUTH_TOKEN, lanternAuthToken);
        }
        return null;
    }
}