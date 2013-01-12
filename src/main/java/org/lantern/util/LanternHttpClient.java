package org.lantern.util;

import org.apache.http.HttpHost;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.impl.client.DefaultHttpClient;
import org.lantern.LanternConstants;

public class LanternHttpClient extends DefaultHttpClient {

    public LanternHttpClient() {
        super();
        final HttpHost proxy = 
            new HttpHost(LanternConstants.FALLBACK_SERVER_HOST, 
                Integer.valueOf(LanternConstants.FALLBACK_SERVER_PORT));
        getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY,proxy);
    }
}
