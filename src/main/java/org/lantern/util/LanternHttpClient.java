package org.lantern.util;

import java.io.IOException;

import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.client.methods.HttpRequestBase;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.conn.scheme.Scheme;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.client.DefaultHttpRequestRetryHandler;
import org.apache.http.params.CoreConnectionPNames;
import org.lantern.Censored;
import org.lantern.LanternConstants;
import org.lantern.LanternSocketsUtil;
import org.lantern.exceptional4j.HttpStrategy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * When we access sites internally within Lantern, we take special care to
 * proxy them as appropriate. These sites include:
 * 
 * docs.google.com (feedback form)
 * exceptional.io -- error reporting
 * query.yahooapis.com (geo data lookup)
 * www.googleapis.com
 * lanternctrl.appspot.com (stats)
 */
@Singleton
public class LanternHttpClient implements HttpStrategy {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final DefaultHttpClient direct = new DefaultHttpClient();
    
    private final DefaultHttpClient proxied = new DefaultHttpClient();

    private final Censored censored;

    /**
     * Whether or not to force censored mode.
     */
    private boolean forceCensored = false;
    
    @Inject
    public LanternHttpClient(final LanternSocketsUtil socketsUtil,
        final Censored censored) {
        this.censored = censored;
        configureDefaults(socketsUtil, direct);
        configureDefaults(socketsUtil, proxied);
        final HttpHost proxy = 
            new HttpHost(LanternConstants.FALLBACK_SERVER_HOST, 
                Integer.valueOf(LanternConstants.FALLBACK_SERVER_PORT), 
                "https");
        proxied.getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY, proxy);
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

    @Override
    public HttpResponse execute(final HttpPost request) 
        throws IOException, ClientProtocolException {
        return executeInternal(request);
    }
    

    @Override
    public HttpResponse execute(final HttpGet request) 
        throws IOException, ClientProtocolException {
        return executeInternal(request);
    }
    
    private HttpResponse executeInternal(final HttpRequestBase request) 
            throws IOException, ClientProtocolException {

        //return proxied.execute(request);
        // We currently disable creating a direct connection *in the 
        // censored case*. The problem is knowing what blocking looks like. 
        // On the one hand, and inability to
        // connect at all should signal going through a proxy. In some cases 
        // it can just take an extremely long time to not connect, however,
        // causing a performance issue regardless. Otherwise, connecting is
        // not necessarily a sign of no blocking -- countries with blocking
        // pages actually are successful connections.
        
        // More work needed to get this fully functional for a fallback case!
        
        // We could theoretically do something like always start with proxying
        // but check the responses to make sure they correspond with the direct
        // versions? 
        
        // We currently just do this if we detect you're not censored.
        if (!this.censored.isCensored() && !forceCensored) {
            return direct.execute(request);
        }
        return proxied.execute(request);
    }

    public DefaultHttpClient getDirect() {
        return this.direct;
    }
    
    public DefaultHttpClient getProxied() {
        return this.proxied;
    }

    public void setForceCensored(final boolean force) {
        this.forceCensored = force;
    }
}
