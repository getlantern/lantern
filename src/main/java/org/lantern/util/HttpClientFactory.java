package org.lantern.util;

import org.apache.http.HttpHost;
import org.apache.http.client.HttpClient;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.conn.scheme.Scheme;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.client.DefaultHttpRequestRetryHandler;
import org.apache.http.params.CoreConnectionPNames;
import org.lantern.Censored;
import org.lantern.LanternClientConstants;
import org.lantern.LanternSocketsUtil;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class HttpClientFactory {

    private final Censored censored;
    private final LanternSocketsUtil socketsUtil;

    @Inject
    public HttpClientFactory(final LanternSocketsUtil socketsUtil, 
            final Censored censored) {
        this.socketsUtil = socketsUtil;
        this.censored = censored;
        
    }
    
    public HttpClient newClient() {
        final DefaultHttpClient client = new DefaultHttpClient();
        configureDefaults(socketsUtil, client);
        if (this.censored.isCensored()) {
            final HttpHost proxy = 
                new HttpHost(LanternClientConstants.FALLBACK_SERVER_HOST, 
                    Integer.valueOf(LanternClientConstants.FALLBACK_SERVER_PORT), 
                    "https");
            client.getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY, proxy);
        }
        return client;
    }
    
    private void configureDefaults(final LanternSocketsUtil socketsUtil,
        final DefaultHttpClient httpClient) {
        // We wrap our own socket factory in HttpClient's socket factory here
        // for a few reasons. First, we use HttpClient's socket factory 
        // because that's the only way to set the custom name verifier we
        // need for accepting the lantern cert on arbitrary proxy addresses.
        // Second, we wrap our ssl socket factory because we need to 
        // dynamically trust new certs as we connect to peers and trust them,
        // we need to reload the trust store and this is the only way to
        // achieve that in conjunction with HttpClient.
        final SSLSocketFactory socketFactory = 
            new SSLSocketFactory(socketsUtil.newTlsSocketFactoryJavaCipherSuites(), 
                new LanternHostNameVerifier());
        final Scheme sch = new Scheme("https", 443, socketFactory);
        httpClient.getConnectionManager().getSchemeRegistry().register(sch);
        
        httpClient.setHttpRequestRetryHandler(new DefaultHttpRequestRetryHandler(2,true));
        httpClient.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 50000);
        httpClient.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 120000);
    }
}
