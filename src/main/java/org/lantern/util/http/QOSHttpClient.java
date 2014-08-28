package org.lantern.util.http;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.http.ConnectionReuseStrategy;
import org.apache.http.client.AuthenticationHandler;
import org.apache.http.client.AuthenticationStrategy;
import org.apache.http.client.HttpRequestRetryHandler;
import org.apache.http.client.RedirectHandler;
import org.apache.http.client.RedirectStrategy;
import org.apache.http.client.RequestDirector;
import org.apache.http.client.UserTokenHandler;
import org.apache.http.conn.ClientConnectionManager;
import org.apache.http.conn.ConnectionKeepAliveStrategy;
import org.apache.http.conn.routing.HttpRoutePlanner;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.params.HttpParams;
import org.apache.http.protocol.HttpProcessor;
import org.apache.http.protocol.HttpRequestExecutor;

/**
 * This is a hacked version of {@link DefaultHttpClient} that exists purely for
 * the purpose of letting us use a {@link QOSRequestDirector}.
 */
public class QOSHttpClient extends DefaultHttpClient {
    private final Log log = LogFactory.getLog(getClass());

    @Override
    protected RequestDirector createClientRequestDirector(
            HttpRequestExecutor requestExec, ClientConnectionManager conman,
            ConnectionReuseStrategy reustrat,
            ConnectionKeepAliveStrategy kastrat, HttpRoutePlanner rouplan,
            HttpProcessor httpProcessor, HttpRequestRetryHandler retryHandler,
            RedirectHandler redirectHandler,
            AuthenticationHandler targetAuthHandler,
            AuthenticationHandler proxyAuthHandler,
            UserTokenHandler userTokenHandler, HttpParams params) {
        return new QOSRequestDirector(
                requestExec,
                conman,
                reustrat,
                kastrat,
                rouplan,
                httpProcessor,
                retryHandler,
                redirectHandler,
                targetAuthHandler,
                proxyAuthHandler,
                userTokenHandler,
                params);
    }

    @Override
    protected RequestDirector createClientRequestDirector(
            HttpRequestExecutor requestExec, ClientConnectionManager conman,
            ConnectionReuseStrategy reustrat,
            ConnectionKeepAliveStrategy kastrat, HttpRoutePlanner rouplan,
            HttpProcessor httpProcessor, HttpRequestRetryHandler retryHandler,
            RedirectStrategy redirectStrategy,
            AuthenticationHandler targetAuthHandler,
            AuthenticationHandler proxyAuthHandler,
            UserTokenHandler userTokenHandler, HttpParams params) {
        return new QOSRequestDirector(
                log,
                requestExec,
                conman,
                reustrat,
                kastrat,
                rouplan,
                httpProcessor,
                retryHandler,
                redirectStrategy,
                targetAuthHandler,
                proxyAuthHandler,
                userTokenHandler,
                params);
    }

    @Override
    protected RequestDirector createClientRequestDirector(
            HttpRequestExecutor requestExec, ClientConnectionManager conman,
            ConnectionReuseStrategy reustrat,
            ConnectionKeepAliveStrategy kastrat, HttpRoutePlanner rouplan,
            HttpProcessor httpProcessor, HttpRequestRetryHandler retryHandler,
            RedirectStrategy redirectStrategy,
            AuthenticationStrategy targetAuthStrategy,
            AuthenticationStrategy proxyAuthStrategy,
            UserTokenHandler userTokenHandler, HttpParams params) {
        return new QOSRequestDirector(
                log,
                requestExec,
                conman,
                reustrat,
                kastrat,
                rouplan,
                httpProcessor,
                retryHandler,
                redirectStrategy,
                targetAuthStrategy,
                proxyAuthStrategy,
                userTokenHandler,
                params);
    }
}
