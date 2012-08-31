package org.lantern.cookie;

import java.util.Set;

import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.CookieDecoder;
import org.jboss.netty.handler.codec.http.CookieEncoder;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** 
 * ChannelUpstreamHandler that filters cookies in an HttpRequest
 * using a CookieFilter 
 */
public class UpstreamCookieFilterHandler extends SimpleChannelUpstreamHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final CookieFilter.Factory cookieFilterFactory;
    
    
    public UpstreamCookieFilterHandler(final CookieFilter cookieFilter) {
        this(CookieUtils.dummyCookieFilterFactory(cookieFilter)); 
    }
    
    public UpstreamCookieFilterHandler(final CookieFilter.Factory cookieFilterFactory) {
        this.cookieFilterFactory = cookieFilterFactory;
    }

    @Override
    public void messageReceived(final ChannelHandlerContext ctx, final MessageEvent evt) throws Exception {
        if (evt.getMessage() instanceof HttpRequest) {
            HttpRequest request = (HttpRequest) evt.getMessage();
            filterCookies(request);
        }
        ctx.sendUpstream(evt);
    }

    /**
     * filters the Cookie header of given HttpRequest using the current CookieFilter.  
     * 
     * A name=value pair in the Cookie header value of the request will be retained
     * if and only if the current CookieFilter accepts the value. If no Cookie name=value
     * pairs exist, the Cookie header is removed from the request.
     */
    public void filterCookies(final HttpRequest request) {
        if (request.containsHeader(HttpHeaders.Names.COOKIE)) {
            final CookieFilter cookieFilter = cookieFilterFactory.createCookieFilter(request);
            if (cookieFilter == null) {
                return;
            }
            
            final String inCookieHeader = request.getHeader(HttpHeaders.Names.COOKIE);
            Set<Cookie> inCookies = null; 
            try {
                inCookies = new CookieDecoder().decode(inCookieHeader);
            }
            catch (IllegalArgumentException e) {
                log.warn("Ignoring malformed cookie header {}: {}", inCookieHeader, e);
                return; 
            }

            // empty or invalid, just ignore without modification
            if (inCookies == null || inCookies.isEmpty()) {
                return;
            }
            
            CookieEncoder outCookies = new CookieEncoder(false);
            
            for (Cookie cookie: inCookies) {
                if (cookieFilter.accepts(cookie)) {
                    log.debug("Permitting upstream cookie {}={} in request to {}",
                              new Object[]{cookie.getName(), cookie.getValue(), request.getUri()});
                    outCookies.addCookie(cookie);
                }
                else {
                    log.debug("Rejecting upstream cookie {}={} in request to {}", 
                              new Object[]{cookie.getName(), cookie.getValue(), request.getUri()});
                }
            }
            final String outCookieHeader = outCookies.encode();
            if (!outCookieHeader.equals(inCookieHeader)) {
                if (outCookieHeader.length() > 0) {
                    request.setHeader(HttpHeaders.Names.COOKIE, outCookieHeader);
                }
                else {
                    request.removeHeader(HttpHeaders.Names.COOKIE);
                }
            }
        }
    }
    
    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        log.error("Caught exception filtering Cookie headers.", e.getCause());
    }
    
}