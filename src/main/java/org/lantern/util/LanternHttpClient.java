package org.lantern.util;

import org.apache.http.HttpHost;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.conn.scheme.Scheme;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.params.CoreConnectionPNames;
import org.lantern.LanternClientSslContextFactory;
import org.lantern.LanternConstants;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LanternHttpClient extends DefaultHttpClient {

    @Inject
    public LanternHttpClient(final LanternClientSslContextFactory factory) {
        super();
        final SSLSocketFactory socketFactory = 
            new SSLSocketFactory(factory.getClientContext());
        final Scheme sch = new Scheme("https", 443, socketFactory);
        getConnectionManager().getSchemeRegistry().register(sch);
        final HttpHost proxy = 
            new HttpHost(LanternConstants.FALLBACK_SERVER_HOST, 
                Integer.valueOf(LanternConstants.FALLBACK_SERVER_PORT), "https");
        getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY,proxy);
        getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 50000);
        getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 120000);
    }
}
