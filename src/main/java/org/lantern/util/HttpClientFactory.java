package org.lantern.util;

import java.net.InetSocketAddress;

import org.apache.http.HttpHost;
import org.apache.http.client.HttpClient;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.conn.scheme.Scheme;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.client.DefaultHttpRequestRetryHandler;
import org.apache.http.params.CoreConnectionPNames;
import org.lantern.Censored;
import org.lantern.LanternSaslGoogleOAuth2Mechanism;
import org.lantern.LanternSocketsUtil;
import org.lantern.ProxyHolder;
import org.lantern.ProxyTracker;
import org.littleshoot.util.FiveTuple;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class HttpClientFactory {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final Censored censored;
    private final LanternSocketsUtil socketsUtil;
    private final ProxyTracker proxyTracker;

    @Inject
    public HttpClientFactory(final LanternSocketsUtil socketsUtil, 
            final Censored censored, final ProxyTracker proxyTracker) {
        this.socketsUtil = socketsUtil;
        this.censored = censored;
        this.proxyTracker = proxyTracker;
        LanternSaslGoogleOAuth2Mechanism.setHttpClientFactory(this);
    }

    public HttpClient newProxiedClient() {
        return newClient(newProxy(), true);
    }
    
    public HttpClient newDirectClient() {
        return newClient(null, false);
    }

    public HttpClient newClient() {
        return newClient(newProxy());
    }

    public HttpHost newProxy() {
        if (this.proxyTracker == null) {
            return null;
        }
        final ProxyHolder ph = proxyTracker.getProxy();
        if (ph == null) {
            return null;
        }
        final FiveTuple ft = ph.getFiveTuple();
        final InetSocketAddress isa = ft.getRemote();
        return new HttpHost(isa.getAddress().getHostAddress(), 
                isa.getPort(), "https");
    }

    public HttpClient newClient(final HttpHost proxy) {
        return newClient(proxy, this.censored.isCensored());
    }
    
    public HttpClient newClient(final HttpHost proxy, final boolean addProxy) {
        final DefaultHttpClient client = new DefaultHttpClient();
        configureDefaults(proxy, client);
        if (addProxy) {
            client.getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY, proxy);
        }
        return client;
    }
    
    private void configureDefaults(final HttpHost proxy, 
        final DefaultHttpClient httpClient) {
        log.debug("Configuring defaults...");
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
                new LanternHostNameVerifier(proxy));
        final Scheme sch = new Scheme("https", 443, socketFactory);
        httpClient.getConnectionManager().getSchemeRegistry().register(sch);
        
        httpClient.setHttpRequestRetryHandler(new DefaultHttpRequestRetryHandler(2,true));
        httpClient.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 50000);
        httpClient.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 120000);
    }
}
