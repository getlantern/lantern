package org.lantern; 

import java.util.Collection;
import java.util.Set;
import static org.junit.Assert.*;

import org.junit.Ignore;
import org.junit.Test;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandler;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.Channels;
import org.jboss.netty.handler.codec.http.CookieEncoder;
import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.HttpHeaders; 
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpResponse;
import org.lantern.cookie.SetCookieObserver;
import org.lantern.cookie.SetCookieObserverHandler;
import static org.lantern.TestingUtils.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Ignore
public class SetCookieObserverHandlerTest {
    
    @Test
    public void testBasicNotification() {
        
        
        final String requestUri = "http://www.example.org/foo";
        
        class ObserverTest implements SetCookieObserver {
            
            public boolean success = false; 
            
            @Override
            public void setCookies(Collection<Cookie> cookies, HttpRequest context) {
                assertFalse(success);
                assertTrue(cookies.size() == 4);
                assertTrue(hasCookieNamed("good", cookies));
                assertTrue(hasCookieNamed("bad", cookies));
                assertTrue(hasCookieNamed("ugly", cookies));
                assertTrue(hasCookieNamed("toadface", cookies));
                assertFalse(hasCookieNamed("normalface", cookies));                
                assertTrue(context.getUri().equals(requestUri));
                success = true; 
            }
        }
        
        final ObserverTest observer = new ObserverTest(); 
        final ChannelHandler handler = new SetCookieObserverHandler(observer);

        final ChannelPipeline pipeline = Channels.pipeline();
        final Channel chan = createDummyChannel(pipeline); 
        pipeline.addLast("set_cookie_observer", handler);
        
        // we have to send an httprequest down the pipeline first
        // to correlate with our response...
        final HttpRequest req = createGetRequest(requestUri);

        // create an HttpResponse with several Set-Cookies in it...
        final HttpResponse res = createResponse();
        CookieEncoder enc = new CookieEncoder(true);
        enc.addCookie("bad", "0");
        String cook = enc.encode();
        res.addHeader(HttpHeaders.Names.SET_COOKIE, cook);
        enc = new CookieEncoder(true);
        enc.addCookie("good", "1");
        cook = enc.encode();
        res.addHeader(HttpHeaders.Names.SET_COOKIE, cook);
        enc = new CookieEncoder(true);
        enc.addCookie("ugly", "2");
        cook = enc.encode();
        res.addHeader(HttpHeaders.Names.SET_COOKIE, cook);
        enc = new CookieEncoder(true);
        enc.addCookie("toadface", "3");
        cook = enc.encode();
        res.addHeader(HttpHeaders.Names.SET_COOKIE, cook);
        //res.setHeader(HttpHeaders.Names.SET_COOKIE, enc.encode());
        
        // make sure everything is there when we start...
        final Set<Cookie> startCookies = extractSetCookies(res);
        assertTrue(startCookies.size() == 4);
        assertTrue(hasCookieNamed("good", startCookies));
        assertTrue(hasCookieNamed("bad", startCookies));
        assertTrue(hasCookieNamed("ugly", startCookies));
        assertTrue(hasCookieNamed("toadface", startCookies));
        assertFalse(hasCookieNamed("normalface", startCookies));

        assertFalse(observer.success);

        // send the fake request...
        pipeline.sendUpstream(createDummyMessageEvent(req));
        
        // XXX should we wait for completion? 
        // then the fake reply...
        pipeline.sendDownstream(createDummyMessageEvent(res));

        // this should trigger the observer with the 
        // expected cookies and info.
        assertTrue(observer.success);

    }
    
    /**
     * test that things do not explode if 
     * the server sends a malformed set-cookie.
     */
    @Test
    public void testMalformedSetCookie() {

        final String requestUri = "http://www.example.org/foo";

        final SetCookieObserverHandlerTest tester = this;
        class ObserverTest implements SetCookieObserver {

            private final Logger log = LoggerFactory.getLogger(getClass());            
            public boolean called = false; 
            
            @Override
            public void setCookies(Collection<Cookie> cookies, HttpRequest context) {
                called = true; 
                log.error("Called with cookies: {}", cookies);
            }
        }
        
        final ObserverTest observer = new ObserverTest();
        final ChannelHandler handler = new SetCookieObserverHandler(observer);

        final ChannelPipeline pipeline = Channels.pipeline();
        final Channel chan = createDummyChannel(pipeline); 
        pipeline.addLast("set_cookie_observer", handler);

        // we have to send an httprequest down the pipeline first
        // to correlate with our response...
        final HttpRequest req = createGetRequest(requestUri);

        final String invalid[] = {" ", ";=;,", "+ +"};
        for (final String val : invalid) {
            // create an HttpResponse with several Set-Cookies in it...
            final HttpResponse res = createResponse();
            res.setHeader(HttpHeaders.Names.SET_COOKIE, val);

            assertTrue(res.getHeader(HttpHeaders.Names.SET_COOKIE).equals(val));

            // send the fake request...
            pipeline.sendUpstream(createDummyMessageEvent(req));

            // then the fake reply...
            pipeline.sendDownstream(createDummyMessageEvent(res));
            
            // header should be unchanged and observer should be uncalled
            assertTrue(res.getHeader(HttpHeaders.Names.SET_COOKIE).equals(val));
            assertFalse(observer.called);
        }
        
    }
    
    /**
     * test that things work and observers are not called
     * in case there are no set-cookie headers in a req/res
     */ 
    @Test
    public void testEmptyNotification() {
        
        final String requestUri = "http://www.example.org/foo";
        
        final SetCookieObserverHandlerTest tester = this;
        class ObserverTest implements SetCookieObserver {
            
            public boolean success = true; 
            
            @Override
            public void setCookies(Collection<Cookie> cookies, HttpRequest context) {
                success = false; // should never be called
            }
        }
        
        final ObserverTest observer = new ObserverTest(); 
        final ChannelHandler handler = new SetCookieObserverHandler(observer);

        final ChannelPipeline pipeline = Channels.pipeline();
        final Channel chan = createDummyChannel(pipeline); 
        pipeline.addLast("set_cookie_observer", handler);
        
        // we have to send an httprequest down the pipeline first
        // to correlate with our response...
        final HttpRequest req = createGetRequest(requestUri);

        // create an HttpResponse with no set-cookies in it...
        final HttpResponse res = createResponse();
        
        // make sure nothing is in there...
        final Set<Cookie> startCookies = extractSetCookies(res);
        assertTrue(startCookies.isEmpty());

        // send the fake request...
        pipeline.sendUpstream(createDummyMessageEvent(req));
        
        // XXX should we wait for completion? 
        // then the fake reply...
        pipeline.sendDownstream(createDummyMessageEvent(res));

        // this should trigger the observer with the 
        // expected cookies and info.
        assertTrue(observer.success);

    }
   
}