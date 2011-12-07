package org.lantern; 

import java.util.Set;
import static org.junit.Assert.*;
import org.junit.Test;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelEvent;
import org.jboss.netty.channel.ChannelHandler;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.Channels;
import org.jboss.netty.handler.codec.http.CookieEncoder;
import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.HttpHeaders; 
import org.jboss.netty.handler.codec.http.HttpRequest; 
import org.lantern.cookie.CookieFilter;
import org.lantern.cookie.UpstreamCookieFilterHandler; 
import static org.lantern.TestingUtils.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;



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
        final Channel chan = createDummyChannel(pipeline); 
        pipeline.addLast("cookie_filter", handler);
        
        // create an HttpRequest with several cookies in it...
        final HttpRequest req = createGetRequest("http://www.example.com/");
        final CookieEncoder enc = new CookieEncoder(false);
        enc.addCookie("bad", "0");
        enc.addCookie("good", "1");
        enc.addCookie("ugly", "2");
        enc.addCookie("toadface", "3");
        req.setHeader(HttpHeaders.Names.COOKIE, enc.encode());
        
        // make sure everything is there when we start...
        final Set<Cookie> startCookies = extractCookies(req);
        assertTrue(startCookies.size() == 4);
        assertTrue(hasCookieNamed("good", startCookies));
        assertTrue(hasCookieNamed("bad", startCookies));
        assertTrue(hasCookieNamed("ugly", startCookies));
        assertTrue(hasCookieNamed("toadface", startCookies));
        assertFalse(hasCookieNamed("normalface", startCookies));

        // push the request through the pipeline
        ChannelEvent fakeEvent = createDummyMessageEvent(req);
        pipeline.sendUpstream(fakeEvent);

        // only the "good" and "toadface" cookie should remain in the request
        final Set<Cookie> endCookies = extractCookies(req);
        assertTrue(endCookies.size() == 2);
        assertTrue(hasCookieNamed("good", endCookies));
        assertFalse(hasCookieNamed("bad", endCookies));
        assertFalse(hasCookieNamed("ugly", endCookies));
        assertTrue(hasCookieNamed("toadface", endCookies));
        assertFalse(hasCookieNamed("normalface", startCookies));

    }
    
    /**
     * if the user agent sends malformed cookie
     * headers, things should not blow up, they 
     * should just pass through.
     */ 
    @Test
    public void testMalformedCookie() {
        
        class TestCookieFilter implements CookieFilter {
            private final Logger log = LoggerFactory.getLogger(getClass());
            
            public boolean called = false;
            
            @Override
            public boolean accepts(Cookie c) {
                called = true;
                log.error("Called with cookie {}", c);
                return false;
            }
        }
        
        final TestCookieFilter cookieFilter = new TestCookieFilter();
        
        // plug it into an UpstreamCookieFilterHandler
        final ChannelHandler handler = new UpstreamCookieFilterHandler(cookieFilter);

        final ChannelPipeline pipeline = Channels.pipeline();
        final Channel chan = createDummyChannel(pipeline);
        pipeline.addLast("cookie_filter", handler);

        // create HttpRequests with invalid cookie headers.. 
        final String invalid[] = {"+ +", " ", "="};
        for (final String val : invalid) {
            final HttpRequest req = createGetRequest("http://www.example.com/");
            req.setHeader(HttpHeaders.Names.COOKIE, val);
            assertTrue(req.getHeader(HttpHeaders.Names.COOKIE).equals(val));

            // push the request through the pipeline
            ChannelEvent fakeEvent = createDummyMessageEvent(req);
            pipeline.sendUpstream(fakeEvent);

            // value should be untouched
            assertTrue(req.getHeader(HttpHeaders.Names.COOKIE).equals(val));
            assertFalse(cookieFilter.called);
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
        final Channel chan = createDummyChannel(pipeline); 
        pipeline.addLast("cookie_filter", handler);

        // create an HttpRequest with no cookies in it...
        final HttpRequest req = createGetRequest("http://www.example.com/");
        
        // make sure nothing is there to start with...
        final Set<Cookie> startCookies = extractCookies(req);
        assertTrue(startCookies.isEmpty());

        // push the request through the pipeline
        ChannelEvent fakeEvent = createDummyMessageEvent(req);
        pipeline.sendUpstream(fakeEvent);

        // there should still be no cookies, and no cookie header
        final Set<Cookie> endCookies = extractCookies(req);
        assertTrue(endCookies.isEmpty());
        assertFalse(req.containsHeader(HttpHeaders.Names.COOKIE));
    }
    
}