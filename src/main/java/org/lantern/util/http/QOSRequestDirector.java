package org.lantern.util.http;

import org.apache.commons.logging.Log;
import org.apache.http.ConnectionReuseStrategy;
import org.apache.http.HttpRequest;
import org.apache.http.client.AuthenticationHandler;
import org.apache.http.client.AuthenticationStrategy;
import org.apache.http.client.HttpRequestRetryHandler;
import org.apache.http.client.RedirectHandler;
import org.apache.http.client.RedirectStrategy;
import org.apache.http.client.UserTokenHandler;
import org.apache.http.conn.ClientConnectionManager;
import org.apache.http.conn.ConnectionKeepAliveStrategy;
import org.apache.http.conn.routing.HttpRoute;
import org.apache.http.conn.routing.HttpRoutePlanner;
import org.apache.http.impl.client.DefaultRequestDirector;
import org.apache.http.params.HttpParams;
import org.apache.http.protocol.HttpContext;
import org.apache.http.protocol.HttpProcessor;
import org.apache.http.protocol.HttpRequestExecutor;
import org.lantern.proxy.pt.Flashlight;

/**
 * This is a hacked version of {@link DefaultRequestDirector} that exists purely
 * to let us set a custom header on the CONNECT request to proxies;
 */
public class QOSRequestDirector extends DefaultRequestDirector {

    @Deprecated
    public QOSRequestDirector(
            final HttpRequestExecutor requestExec,
            final ClientConnectionManager conman,
            final ConnectionReuseStrategy reustrat,
            final ConnectionKeepAliveStrategy kastrat,
            final HttpRoutePlanner rouplan,
            final HttpProcessor httpProcessor,
            final HttpRequestRetryHandler retryHandler,
            final RedirectHandler redirectHandler,
            final AuthenticationHandler targetAuthHandler,
            final AuthenticationHandler proxyAuthHandler,
            final UserTokenHandler userTokenHandler,
            final HttpParams params) {
        super(requestExec, conman, reustrat, kastrat, rouplan, httpProcessor,
                retryHandler, redirectHandler, targetAuthHandler,
                proxyAuthHandler, userTokenHandler, params);
    }

    @Deprecated
    public QOSRequestDirector(
            final Log log,
            final HttpRequestExecutor requestExec,
            final ClientConnectionManager conman,
            final ConnectionReuseStrategy reustrat,
            final ConnectionKeepAliveStrategy kastrat,
            final HttpRoutePlanner rouplan,
            final HttpProcessor httpProcessor,
            final HttpRequestRetryHandler retryHandler,
            final RedirectStrategy redirectStrategy,
            final AuthenticationHandler targetAuthHandler,
            final AuthenticationHandler proxyAuthHandler,
            final UserTokenHandler userTokenHandler,
            final HttpParams params) {
        super(log, requestExec, conman, reustrat, kastrat, rouplan,
                httpProcessor, retryHandler, redirectStrategy,
                targetAuthHandler, proxyAuthHandler, userTokenHandler, params);
    }

    public QOSRequestDirector(
            final Log log,
            final HttpRequestExecutor requestExec,
            final ClientConnectionManager conman,
            final ConnectionReuseStrategy reustrat,
            final ConnectionKeepAliveStrategy kastrat,
            final HttpRoutePlanner rouplan,
            final HttpProcessor httpProcessor,
            final HttpRequestRetryHandler retryHandler,
            final RedirectStrategy redirectStrategy,
            final AuthenticationStrategy targetAuthStrategy,
            final AuthenticationStrategy proxyAuthStrategy,
            final UserTokenHandler userTokenHandler,
            final HttpParams params) {
        super(log, requestExec, conman, reustrat, kastrat, rouplan,
                httpProcessor, retryHandler, redirectStrategy,
                targetAuthStrategy, proxyAuthStrategy, userTokenHandler, params);
    }

    @Override
    protected HttpRequest createConnectRequest(HttpRoute route,
            HttpContext context) {
        HttpRequest request = super.createConnectRequest(route, context);
        request.setHeader(Flashlight.X_FLASHLIGHT_QOS, Integer.toString(Flashlight.HIGH_QOS));
        return request;
    }
}
