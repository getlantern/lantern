package org.lantern.cookie;

import java.util.ArrayList;
import java.util.List;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelHandler;
import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.CookieDecoder;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpResponse;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * A ChannelHander that observes downstream Set-Cookie headers in HttpResponses
 * and passes them to a SetCookieObserver. 
 */
public class SetCookieObserverHandler extends SimpleChannelHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());

    // tracks original upstream requests to correlate with downstream cookies
    private final Queue<HttpRequest> requests; 
    private final SetCookieObserver observer;

    public SetCookieObserverHandler() {
        this(null);
    }

    public SetCookieObserverHandler(final SetCookieObserver observer) {
        this.requests = new ConcurrentLinkedQueue<HttpRequest>();
        this.observer = observer;
    }

    @Override
    public void messageReceived(final ChannelHandlerContext ctx, final MessageEvent evt) throws Exception {
        // track request information to relate with response information. 
        // A clone of the reqeust is tracked because the request URI and other 
        // parts of the request can be mutated downstream for various reasons 
        // (eg LaeHttpRequestTransformer)
        if (evt.getMessage() instanceof HttpRequest) {
            final HttpRequest request = (HttpRequest) evt.getMessage();            
            requests.add(CookieUtils.copyHttpRequestInfo(request));
        }
        ctx.sendUpstream(evt);
    }

    @Override
    public void writeRequested(final ChannelHandlerContext ctx, final MessageEvent evt) {
        if (evt.getMessage() instanceof HttpResponse) {
            final HttpResponse response = (HttpResponse) evt.getMessage();
            handleSetCookies(response);
        }
        ctx.sendDownstream(evt);
    }
    
    /**
     * called to decode and handle Set-Cookie headers in 
     * an HttpResponse.  calls handleSetCookie on each.
     *
     */
    void handleSetCookies(final HttpResponse response) {
        // pop the request corresponding to this response.
        final HttpRequest request = requests.remove();
        // if anyone is listening, gather up the set-cookies in the request
        // and pass them along.
        if (this.observer != null && response.containsHeader(HttpHeaders.Names.SET_COOKIE)) {
            final List<String> setCookieHeaders = response.getHeaders(HttpHeaders.Names.SET_COOKIE);
            final List<Cookie> setCookies = new ArrayList<Cookie>();
            final CookieDecoder decoder = new CookieDecoder();
            for (String setCookieHeader: setCookieHeaders) {
                try {
                    for (Cookie c : decoder.decode(setCookieHeader)) {
                        setCookies.add(c);
                    }
                }
                catch (IllegalArgumentException e) {
                    log.warn("Ignoring response with unparsable set-cookie header:" + setCookieHeader, e);
                }
            }
            if (!setCookies.isEmpty()) {
                this.observer.setCookies(setCookies, request);
            }
        }
    }

    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        log.error("Caught exception observing Set-Cookie headers: {}", e.getCause());
    }

}