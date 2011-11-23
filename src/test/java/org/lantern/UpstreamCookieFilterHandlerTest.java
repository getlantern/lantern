package org.lantern; 

import java.net.SocketAddress;
import java.util.HashSet;
import java.util.Set;
import static org.junit.Assert.*;
import org.junit.Test;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelEvent;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelHandler;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.Channels;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.handler.codec.http.CookieEncoder;
import org.jboss.netty.handler.codec.http.CookieDecoder;
import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.DefaultHttpRequest;
import org.jboss.netty.handler.codec.http.HttpHeaders; 
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest; 
import org.jboss.netty.handler.codec.http.HttpVersion;
import org.lantern.cookie.CookieFilter;
import org.lantern.cookie.UpstreamCookieFilterHandler; 

public class UpstreamCookieFilterHandlerTest {
    
    @Test
    public void testBasicFiltering() {
        // create a simple CookieFilter that only accepts 
        // outbound cookies that have the name "good" or "toadface"
        final CookieFilter cookieFilter = new CookieFilter() {
            @Override
            public boolean accepts(Cookie c) {
                return c.getName().equals("good") || c.getName().equals("toadface");
            }
        };
        // plug it into an UpstreamCookieFilterHandler
        final ChannelHandler handler = new UpstreamCookieFilterHandler(cookieFilter);

        final ChannelPipeline pipeline = Channels.pipeline(); 
        pipeline.addLast("cookie_filter", handler);
        
        // create an HttpRequest with several cookies in it...
        final HttpRequest req = _makeGetRequest("http://www.example.com/");
        final CookieEncoder enc = new CookieEncoder(false);
        enc.addCookie("bad", "0");
        enc.addCookie("good", "1");
        enc.addCookie("ugly", "2");
        enc.addCookie("toadface", "3");
        req.setHeader(HttpHeaders.Names.COOKIE, enc.encode());
        
        // make sure everything is there when we start...
        final Set<Cookie> startCookies = _getCookies(req);
        assertTrue(startCookies.size() == 4);
        assertTrue(_hasCookieNamed("good", startCookies));
        assertTrue(_hasCookieNamed("bad", startCookies));
        assertTrue(_hasCookieNamed("ugly", startCookies));
        assertTrue(_hasCookieNamed("toadface", startCookies));
        assertFalse(_hasCookieNamed("normalface", startCookies));

        // push the request through the pipeline
        ChannelEvent fakeEvent = _fakeMessageEvent(req);
        pipeline.sendUpstream(fakeEvent);

        // only the "good" and "toadface" cookie should remain in the request
        final Set<Cookie> endCookies = _getCookies(req);
        assertTrue(endCookies.size() == 2);
        assertTrue(_hasCookieNamed("good", endCookies));
        assertFalse(_hasCookieNamed("bad", endCookies));
        assertFalse(_hasCookieNamed("ugly", endCookies));
        assertTrue(_hasCookieNamed("toadface", endCookies));
        assertFalse(_hasCookieNamed("normalface", startCookies));

    }
    
    /**
     * if the user agent sends malformed cookie
     * headers, things should not blow up, they 
     * should just pass through.
     */ 
    @Test
    public void testMalformedCookie() {
        
        // create a simple CookieFilter that 
        // explodes if called.
        final CookieFilter cookieFilter = new CookieFilter() {
            @Override
            public boolean accepts(Cookie c) {
                assertTrue(false);
                return false;
            }
        };
        // plug it into an UpstreamCookieFilterHandler
        final ChannelHandler handler = new UpstreamCookieFilterHandler(cookieFilter);

        final ChannelPipeline pipeline = Channels.pipeline(); 
        pipeline.addLast("cookie_filter", handler);
        
        // create HttpRequests with invalid cookie headers.. 
        final String invalid[] = {"zKLJ@!3_#", " ", "="};
        for (final String val : invalid) {
            final HttpRequest req = _makeGetRequest("http://www.example.com/");
            req.setHeader(HttpHeaders.Names.COOKIE, val);
            assertTrue(req.getHeader(HttpHeaders.Names.COOKIE).equals(val));

            // push the request through the pipeline
            ChannelEvent fakeEvent = _fakeMessageEvent(req);
            pipeline.sendUpstream(fakeEvent);

            // value should be untouched
            assertTrue(req.getHeader(HttpHeaders.Names.COOKIE).equals(val));
        }
    }
    
    
    /**
     * The handler should not do anything in particular 
     * if there are no Cookie headers in the request.
     */
    @Test
    public void testEmptyFiltering() {
        // create a simple CookieFilter that only accepts anything
        final CookieFilter cookieFilter = new CookieFilter() {
            @Override
            public boolean accepts(Cookie c) {
                return true;
            }
        };
        // plug it into an UpstreamCookieFilterHandler
        final ChannelHandler handler = new UpstreamCookieFilterHandler(cookieFilter);

        final ChannelPipeline pipeline = Channels.pipeline(); 
        pipeline.addLast("cookie_filter", handler);
        
        // create an HttpRequest with no cookies in it...
        final HttpRequest req = _makeGetRequest("http://www.example.com/");
        
        // make sure nothing is there to start with...
        final Set<Cookie> startCookies = _getCookies(req);
        assertTrue(startCookies.isEmpty());

        // push the request through the pipeline
        ChannelEvent fakeEvent = _fakeMessageEvent(req);
        pipeline.sendUpstream(fakeEvent);

        // there should still be no cookies, and no cookie header
        final Set<Cookie> endCookies = _getCookies(req);
        assertTrue(endCookies.isEmpty());
        assertFalse(req.containsHeader(HttpHeaders.Names.COOKIE));
    }

    private boolean _hasCookieNamed(final String cookieName, final Set<Cookie> cookies) {
        for (Cookie c : cookies) {
            if (c.getName().equals(cookieName)) {
                return true;
            }
        }
        return false;
    }
    
    private Set<Cookie> _getCookies(HttpRequest req) {
        if (req.containsHeader(HttpHeaders.Names.COOKIE)) {
            final String header = req.getHeader(HttpHeaders.Names.COOKIE);
            return new CookieDecoder().decode(header);
        }
        else {
            return new HashSet<Cookie>();
        }
    }
    
    private HttpRequest _makeGetRequest(final String uri) {
        return new DefaultHttpRequest(HttpVersion.HTTP_1_1, HttpMethod.GET, uri);
    }
    
    private MessageEvent _fakeMessageEvent(final Object message) {
        return new MessageEvent() {
            @Override
            public Object getMessage() {
                return message;
            }
            
            @Override
            public SocketAddress getRemoteAddress() {
                return null;
            }
            
            @Override
            public Channel getChannel() {
                return null;
            }
            
            @Override
            public ChannelFuture getFuture() {
                return null;
            }
        };
    }
    
}