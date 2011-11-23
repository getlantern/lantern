package org.lantern; 

import java.net.SocketAddress;
import java.util.Collection;
import java.util.HashSet;
import java.util.Set;
import static org.junit.Assert.*;
import org.junit.Test;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelHandler;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.Channels;
import org.jboss.netty.channel.DefaultChannelFuture;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.handler.codec.http.CookieEncoder;
import org.jboss.netty.handler.codec.http.CookieDecoder;
import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.DefaultHttpRequest;
import org.jboss.netty.handler.codec.http.DefaultHttpResponse;
import org.jboss.netty.handler.codec.http.HttpHeaders; 
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpResponse;
import org.jboss.netty.handler.codec.http.HttpResponseStatus;
import org.jboss.netty.handler.codec.http.HttpVersion;
import org.lantern.cookie.SetCookieObserver;
import org.lantern.cookie.SetCookieObserverHandler;

public class SetCookieObserverHandlerTest {
    
    @Test
    public void testBasicNotification() {
        
        
        final String requestUri = "http://www.example.org/foo";
        
        final SetCookieObserverHandlerTest tester = this;
        class ObserverTest implements SetCookieObserver {
            
            public boolean success = false; 
            
            @Override
            public void setCookies(Collection<Cookie> cookies, HttpRequest context) {
                assertFalse(success);
                assertTrue(cookies.size() == 4);
                assertTrue(tester._hasCookieNamed("good", cookies));
                assertTrue(tester._hasCookieNamed("bad", cookies));
                assertTrue(tester._hasCookieNamed("ugly", cookies));
                assertTrue(tester._hasCookieNamed("toadface", cookies));
                assertFalse(tester._hasCookieNamed("normalface", cookies));                
                assertTrue(context.getUri().equals(requestUri));
                success = true; 
            }
        }
        
        final ObserverTest observer = new ObserverTest(); 
        final ChannelHandler handler = new SetCookieObserverHandler(observer);

        final ChannelPipeline pipeline = Channels.pipeline(); 
        pipeline.addLast("set_cookie_observer", handler);
        
        // we have to send an httprequest down the pipeline first
        // to correlate with our response...
        final HttpRequest req = _makeGetRequest(requestUri);

        // create an HttpResponse with several Set-Cookies in it...
        final HttpResponse res = _makeResponse();
        final CookieEncoder enc = new CookieEncoder(true);
        enc.addCookie("bad", "0");
        enc.addCookie("good", "1");
        enc.addCookie("ugly", "2");
        enc.addCookie("toadface", "3");
        res.setHeader(HttpHeaders.Names.SET_COOKIE, enc.encode());
        
        // make sure everything is there when we start...
        final Set<Cookie> startCookies = _getResCookies(res);
        assertTrue(startCookies.size() == 4);
        assertTrue(_hasCookieNamed("good", startCookies));
        assertTrue(_hasCookieNamed("bad", startCookies));
        assertTrue(_hasCookieNamed("ugly", startCookies));
        assertTrue(_hasCookieNamed("toadface", startCookies));
        assertFalse(_hasCookieNamed("normalface", startCookies));

        assertFalse(observer.success);

        // send the fake request...
        pipeline.sendUpstream(_fakeMessageEvent(req));
        
        // XXX should we wait for completion? 
        // then the fake reply...
        pipeline.sendDownstream(_fakeMessageEvent(res));

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
            
            public boolean success = true; 
            
            @Override
            public void setCookies(Collection<Cookie> cookies, HttpRequest context) {
                success = false; // should never be called
            }
        }
        
        final ObserverTest observer = new ObserverTest();
        final ChannelHandler handler = new SetCookieObserverHandler(observer);

        final ChannelPipeline pipeline = Channels.pipeline(); 
        pipeline.addLast("set_cookie_observer", handler);

        // we have to send an httprequest down the pipeline first
        // to correlate with our response...
        final HttpRequest req = _makeGetRequest(requestUri);

        final String invalid[] = {" ", ";=;,"};
        for (final String val : invalid) {
            // create an HttpResponse with several Set-Cookies in it...
            final HttpResponse res = _makeResponse();
            res.setHeader(HttpHeaders.Names.SET_COOKIE, val);

            assertTrue(res.getHeader(HttpHeaders.Names.SET_COOKIE).equals(val));

            // send the fake request...
            pipeline.sendUpstream(_fakeMessageEvent(req));

            // then the fake reply...
            pipeline.sendDownstream(_fakeMessageEvent(res));
            
            // header should be unchanged and observer should be uncalled
            assertTrue(res.getHeader(HttpHeaders.Names.SET_COOKIE).equals(val));
            assertTrue(observer.success);
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
        pipeline.addLast("set_cookie_observer", handler);
        
        // we have to send an httprequest down the pipeline first
        // to correlate with our response...
        final HttpRequest req = _makeGetRequest(requestUri);

        // create an HttpResponse with no set-cookies in it...
        final HttpResponse res = _makeResponse();
        
        // make sure nothing is in there...
        final Set<Cookie> startCookies = _getResCookies(res);
        assertTrue(startCookies.isEmpty());

        // send the fake request...
        pipeline.sendUpstream(_fakeMessageEvent(req));
        
        // XXX should we wait for completion? 
        // then the fake reply...
        pipeline.sendDownstream(_fakeMessageEvent(res));

        // this should trigger the observer with the 
        // expected cookies and info.
        assertTrue(observer.success);

    }



    private boolean _hasCookieNamed(final String cookieName, final Collection<Cookie> cookies) {
        for (Cookie c : cookies) {
            if (c.getName().equals(cookieName)) {
                return true;
            }
        }
        return false;
    }
    
    private Set<Cookie> _getResCookies(HttpResponse res) {
        if (res.containsHeader(HttpHeaders.Names.SET_COOKIE)) {
            final String header = res.getHeader(HttpHeaders.Names.SET_COOKIE);
            return new CookieDecoder().decode(header);
        }
        else {
            return new HashSet<Cookie>();
        }
    }

    private HttpResponse _makeResponse() {
        return new DefaultHttpResponse(HttpVersion.HTTP_1_1, HttpResponseStatus.OK);
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
                return new DefaultChannelFuture(null, true) {
                    @Override
                    public boolean setFailure(Throwable t) {
                        t.printStackTrace();
                        return true;
                    }
                };
            }
        };
    }
    
}