package org.lantern.util;

import java.io.IOException;
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
import org.lantern.LanternSocketsUtil;
import org.lantern.LanternUtils;
import org.lantern.ProxyHolder;
import org.lantern.ProxyTracker;
import org.littleshoot.util.FiveTuple;
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
    }

    /**
     * Returns a proxied client if we have access to a proxy in get mode.
     * 
     * @return The proxied {@link HttpClient} if available in get mode, 
     * otherwise an unproxied client.
     * @throws IOException If we could not obtain a proxied client.
     */
    public HttpClient newProxiedClient() throws IOException {
        if (LanternUtils.isGet()) {
            try {
                return newClient(newProxyBlocking(), true);
            } catch (InterruptedException e) {
                throw new IOException("Could not access proxy!", e);
            }
        }
        
        // Just return a direct client if we haven't been able to connect
        // to a proxy.
        return newClient(null, true);
    }
    
    public HttpClient newDirectClient() {
        return newClient(null, false);
    }

    public HttpClient newClient() {
        return newClient(newProxy());
    }

    private HttpHost newProxy() {
        // Can be empty for testing.
        if (this.proxyTracker == null) {
            return null;
        }
        final ProxyHolder ph = proxyTracker.firstConnectedTcpProxy();
        if (ph == null) {
            return null;
        }
        final FiveTuple ft = ph.getFiveTuple();
        final InetSocketAddress isa = ft.getRemote();
        return new HttpHost(isa.getAddress().getHostAddress(), 
                isa.getPort(), "https");
    }
    

    public HttpHost newProxyBlocking() throws InterruptedException {
        // Can be empty for testing.
        if (this.proxyTracker == null) {
            return null;
        }
        final ProxyHolder ph = proxyTracker.firstConnectedTcpProxyBlocking();
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
