package org.lantern.util;

import org.apache.http.HttpHost;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.conn.scheme.Scheme;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.params.CoreConnectionPNames;
import org.lantern.LanternConstants;
import org.lantern.LanternSocketsUtil;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LanternHttpClient extends DefaultHttpClient {

    @Inject
    public LanternHttpClient(final LanternSocketsUtil socketsUtil) {
        // We wrap our own socket factory in HttpClient's socket factory here
        // for a few reasons. First, we use HttpClient's socket factory 
        // because that's the only way to set the custom name verifier we
        // need for accepting the lantern cert on arbitrary proxy addresses.
        // Second, we wrap our ssl socket factory because we need to 
        // dynamically trust new certs as we connect to peers and trust them,
        // we need to reload the trust store and this is the only way to
        // achieve that in conjunction with HttpClient.
        final SSLSocketFactory socketFactory = 
            new SSLSocketFactory(socketsUtil.newTlsSocketFactory(), 
                new LanternHostNameVerifier());
        
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
