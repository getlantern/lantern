package org.lantern.util;

import java.io.IOException;

import javax.net.ssl.SSLContext;

import org.apache.commons.lang.math.RandomUtils;
import org.apache.http.HttpException;
import org.apache.http.HttpHost;
import org.apache.http.HttpRequest;
import org.apache.http.HttpRequestInterceptor;
import org.apache.http.client.HttpClient;
import org.apache.http.conn.ClientConnectionManager;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.conn.scheme.PlainSocketFactory;
import org.apache.http.conn.scheme.Scheme;
import org.apache.http.conn.scheme.SchemeRegistry;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.client.DefaultHttpRequestRetryHandler;
import org.apache.http.impl.conn.SingleClientConnManager;
import org.apache.http.params.CoreConnectionPNames;
import org.apache.http.protocol.HttpContext;
import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
import org.lantern.NoSSLv2SocketFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for handling HTTP client interaction.
 */
public class StaticHttpClientFactory {

    private static final Logger log = 
            LoggerFactory.getLogger(StaticHttpClientFactory.class);
    
    public static HttpClient newDirectClient() {
        return newDirectClient(null);
    }
    
    public static HttpClient newDirectClient(SSLContext sslContext) {
        log.debug("Returning direct client");
        return newClient(sslContext, null);
    }

    public static HttpClient newProxiedClient() {
        return newProxiedClient(null);
    }
    
    public static HttpClient newProxiedClient(SSLContext sslContext) {
        log.debug("Returning proxied client");
        HttpHost proxy = new HttpHost("127.0.0.1",
                LanternConstants.LANTERN_LOCALHOST_HTTP_PORT,
                "http");
        return newClient(sslContext, proxy);
    }

    public static HttpClient newClient(SSLContext sslContext, final HttpHost proxy) {
        final DefaultHttpClient client;
        if (sslContext == null) {
            client = new DefaultHttpClient();
        } else {
            // Caller specified a custom sslContext, use that
            javax.net.ssl.SSLSocketFactory jsf =
                    new NoSSLv2SocketFactory(sslContext.getSocketFactory());
            SSLSocketFactory sf = new SSLSocketFactory(jsf, SSLSocketFactory.BROWSER_COMPATIBLE_HOSTNAME_VERIFIER);
            Scheme httpScheme = new Scheme("http", 80, PlainSocketFactory.getSocketFactory());
            Scheme httpsScheme = new Scheme("https", 443, sf);
            SchemeRegistry schemeRegistry = new SchemeRegistry();
            schemeRegistry.register(httpScheme);
            schemeRegistry.register(httpsScheme);
            ClientConnectionManager cm = new SingleClientConnManager(schemeRegistry);
            client = new DefaultHttpClient(cm);
        }
        
        // Add a random length header to avoid repeated messages of the same
        // size on the network.
        client.addRequestInterceptor(new HttpRequestInterceptor() {
            
            @Override
            public void process(final HttpRequest request, 
                    final HttpContext context)
                    throws HttpException, IOException {
                
                request.addHeader("Lan-Rand", randomLengthVal());
            }
        });
        client.setHttpRequestRetryHandler(new DefaultHttpRequestRetryHandler(3,true));
        client.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 50000);
        client.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 120000);
        if (proxy != null) {
            client.getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY, proxy);
            LanternUtils.waitForServer(proxy.getHostName(), proxy.getPort(), 10000);
        }
        return client;
    }
    
    /**
     * Creates a random length header value to avoid same length requests.
     * Note these should always be sent over an encrypted connection, so the
     * actual characters don't matter.
     * 
     * @return A random length string.
     */
    private static String randomLengthVal() {
        final int length = RandomUtils.nextInt() % 60;
        final StringBuilder sb = new StringBuilder();
        for (int i = 0; i < length; i++) {
            sb.append(i);
        }
        return sb.toString();
    }
}
