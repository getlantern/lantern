package org.lantern.util;

import java.security.KeyManagementException;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.UnrecoverableKeyException;

import org.apache.http.HttpHost;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.conn.scheme.Scheme;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.params.CoreConnectionPNames;
import org.lantern.LanternConstants;

public class LanternHttpClient extends DefaultHttpClient {

    public LanternHttpClient() {
        super();
        
        // We use the lantern host name verifier here purely because we need
        // the host name of our fallback proxy servers to be accepted. For all
        // other hosts it uses the strict host name verifier.
        final SSLSocketFactory socketFactory;
        try {
            socketFactory = new SSLSocketFactory(SSLSocketFactory.TLS, null, 
                null, null, null, null, new LanternHostNameVerifier());
        } catch (final KeyManagementException e) {
            throw new Error("Could not configure factory?", e);
        } catch (final UnrecoverableKeyException e) {
            throw new Error("Could not configure factory?", e);
        } catch (final NoSuchAlgorithmException e) {
            throw new Error("Could not configure factory?", e);
        } catch (final KeyStoreException e) {
            throw new Error("Could not configure factory?", e);
        }
        
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
