package org.lantern.util;

import org.apache.http.HttpHost;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.params.CoreConnectionPNames;
import org.lantern.LanternConstants;

public class LanternHttpClient extends DefaultHttpClient {

    public LanternHttpClient() {
        super();
        final HttpHost proxy = 
            new HttpHost(LanternConstants.FALLBACK_SERVER_HOST, 
                Integer.valueOf(LanternConstants.FALLBACK_SERVER_PORT), "https");
        getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY,proxy);
        getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 50000);
        getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 120000);
    }
}
