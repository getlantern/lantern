package org.lantern.util;

import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.params.ClientPNames;
import org.apache.http.client.params.CookiePolicy;
import org.apache.http.params.CoreConnectionPNames;

/**
 * Implements an HTTP Get using host spoofing.
 */
public class HostSpoofedHTTPGet {
    private final HttpClient client;
    private final String realHost;
    private final HttpHost masqueradeHost;

    public HostSpoofedHTTPGet(HttpClient client,
            String realHost,
            String masqueradeHost) {
        this.client = client;
        this.realHost = realHost;
        this.masqueradeHost = new HttpHost(masqueradeHost, 443, "https");
    }

    public <T> T get(String path, ResponseHandler<T> handler) {
        HttpGet request = new HttpGet(path);
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
                    .execute(masqueradeHost, request));
        } catch (Exception e) {
            return handler.onException(e);
        } finally {
            request.releaseConnection();
        }
    }

    public static interface ResponseHandler<T> {
        T onResponse(HttpResponse response) throws Exception;

        T onException(Exception e);
    }
}
