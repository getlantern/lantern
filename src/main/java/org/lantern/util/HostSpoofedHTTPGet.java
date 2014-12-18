package org.lantern.util;

import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.params.ClientPNames;
import org.apache.http.client.params.CookiePolicy;
import org.apache.http.params.CoreConnectionPNames;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Implements an HTTP Get using host spoofing.
 */
public class HostSpoofedHTTPGet {
    private static final Logger LOGGER = LoggerFactory
            .getLogger(HostSpoofedHTTPGet.class);

    private final HttpClient client;
    private final String realHost;
    private final HttpHost masqueradeHost;

    public HostSpoofedHTTPGet(HttpClient client,
            String realHost,
            String masqueradeHost) {
        this.client = client;
        this.realHost = realHost;
        this.masqueradeHost = new HttpHost(masqueradeHost,443, "https");
    }

    public <T> T get(String path, ResponseHandler<T> handler) {
        Exception finalException = null;
        // Try the request with all available masquerade hosts until one
        // succeeds.
        try {
            return doGet(masqueradeHost, path, handler);
        } catch (Exception e) {
            LOGGER.warn(
                    "Caught exception using masqueradeHost {}, could mean that it's blocked: {}",
                    masqueradeHost, e.getMessage(), e);
            finalException = e;
        }

        // None of the requests worked, handle the exception
        return handler.onException(finalException);
    }

    private <T> T doGet(HttpHost host, String path,
            ResponseHandler<T> handler)
            throws Exception {
        HttpGet request = new HttpGet(path);
        LOGGER.info("Seeing host header to {}", realHost);
        request.setHeader("Host", realHost);
        try {
            request.getParams().setParameter(
                    CoreConnectionPNames.CONNECTION_TIMEOUT, 60000);
            request.getParams().setParameter(
                    ClientPNames.HANDLE_REDIRECTS, false);
            // Ignore cookies because host spoofing will return cookies that
            // don't match the requested domain
            request.getParams().setParameter(
                    ClientPNames.COOKIE_POLICY, CookiePolicy.IGNORE_COOKIES);
            // Unable to set SO_TIMEOUT because of bug in Java 7
            // See https://github.com/getlantern/lantern/issues/942
            // request.getParams().setParameter(
            // CoreConnectionPNames.SO_TIMEOUT, 60000);
            return handler.onResponse(client
                    .execute(host, request));
        } finally {
            request.releaseConnection();
        }
    }

    public static interface ResponseHandler<T> {
        T onResponse(HttpResponse response) throws Exception;

        T onException(Exception e);
    }
}
