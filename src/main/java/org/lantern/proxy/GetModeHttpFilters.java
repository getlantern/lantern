package org.lantern.proxy;

import io.netty.handler.codec.http.HttpObject;
import io.netty.handler.codec.http.HttpRequest;
import io.netty.handler.codec.http.HttpResponse;

import org.lantern.util.RandomLengthString;
import org.littleshoot.proxy.HttpFilters;
import org.littleshoot.proxy.HttpFiltersAdapter;

/**
 * {@link HttpFilters} used by the Get mode proxy.
 */
public class GetModeHttpFilters extends HttpFiltersAdapter {
    private static final RandomLengthString RANDOM_LENGTH_STRING =
            new RandomLengthString(100);

    public static final String X_LANTERN_AUTH_TOKEN = "X-LANTERN-AUTH-TOKEN";
    public static final String X_LANTERN_RANDOM_LENGTH_HEADER = "X_LANTERN-RANDOM-LENGTH-HEADER";

    private final String lanternAuthToken;

    public GetModeHttpFilters(String lanternAuthToken,
            HttpRequest originalRequest) {
        super(originalRequest);
        this.lanternAuthToken = lanternAuthToken;
    }

    @Override
    public HttpResponse requestPre(HttpObject httpObject) {
        if (httpObject instanceof HttpRequest) {
            HttpRequest httpRequest = (HttpRequest) httpObject;
            if (lanternAuthToken != null) {
                // Add an auth token to authenticate with the Give mode proxy
                httpRequest.headers().add(X_LANTERN_AUTH_TOKEN,
                        lanternAuthToken);
            }
            // Add a random length header to help foil fingerprinting
            httpRequest.headers().add(X_LANTERN_RANDOM_LENGTH_HEADER,
                    RANDOM_LENGTH_STRING.next());
        }
        return super.requestPre(httpObject);
    }

}
