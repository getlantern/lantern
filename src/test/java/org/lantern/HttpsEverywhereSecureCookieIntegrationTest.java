package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.lantern.TestingUtils.extractCookies;
import static org.lantern.TestingUtils.extractSetCookies;

import java.util.Set;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.CookieEncoder;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpResponse;
import org.junit.BeforeClass;
import org.junit.Test;

public class HttpsEverywhereSecureCookieIntegrationTest {
    
    
    @BeforeClass
    public static void setup() {
        LanternHub.resetSettings(false);
    }
    
    /**
     * These tests check that things come through the 
     * lantern client pipeline correctly when using 
     * the https everywhere secure cookie filter. 
     *  
     * these test should include all lantern 
     * observable "plaintext" request types that
     * should have secure cookie handling. 
     */ 
    
    @Test
    public void testTrustedPeerProxy() throws Exception {
        doSecureCookieTest(new MockTrustedConnection());
    }

    /** 
     * this tests the "general proxy" case.
     */ 
    @Test
    public void testGeneralProxy() throws Exception {
        doSecureCookieTest(new MockProxyConnection());
    }

    /** 
     * this tests the app-engine case 
     */
    @Test
    public void testLae() throws Exception {
        doSecureCookieTest(new MockLaeConnection());
    }
    
    private void doSecureCookieTest(final MockConnection conn) throws Exception {
        try {
  
            // fake.twitter.com will trigger HTTSEverywhere secure-cookie, but not a redirect.
            final String testHost = "fake.twitter.com";


            // first just check that we can get a request through with no issues 
            // by threading a random header through.
            final String testName = "X-Lantern-Foo";
            final String testValue = "Z3K437";
            final String testValue2 = "734K3Z";
            
            conn.runTest(new RoundTripTest() {        
                @Override
                public HttpRequest createRequest() throws Exception {
                    final HttpRequest req = conn.createBaseRequest(testHost);
                    req.setHeader(testName, testValue);
                    return req;
                }

                @Override
                public HttpResponse createResponse(final HttpRequest request, final Channel origin) throws Exception {
                    final HttpResponse res = TestingUtils.createResponse("", origin.getConfig().getBufferFactory());
                    res.setHeader(testName, request.getHeader(testName));
                    return res;
                }

                @Override
                public void handleResponse(final HttpResponse res) throws Exception {
                    assertEquals(res.getHeader(testName), testValue);
                }
            });

            // try to send a cookie through, it should be clipped by the very 
            // aggressive twitter cookie filter in the rules... 
            // on the way back we'll set this cookie.
            conn.runTest(new RoundTripTest() {        
                @Override
                public HttpRequest createRequest() throws Exception {
                    final HttpRequest req = conn.createBaseRequest(testHost);
                    
                    CookieEncoder enc = new CookieEncoder(false);
                    enc.addCookie(testName, testValue);
                    req.setHeader(HttpHeaders.Names.COOKIE, enc.encode());
                    return req;
                }
            
                @Override
                public HttpResponse createResponse(final HttpRequest request, final Channel origin) throws Exception {
                    // here we should see no cookie header coming through, it will have been clipped out entirely...
                    assertTrue(request.getHeader(HttpHeaders.Names.COOKIE) == null);
                    
                    // now, we'll send it back in order to "whitelist it"...
                    final HttpResponse res = TestingUtils.createResponse("", origin.getConfig().getBufferFactory());
                    CookieEncoder enc = new CookieEncoder(true);
                    enc.addCookie(testName, testValue);
                    res.setHeader(HttpHeaders.Names.SET_COOKIE, enc.encode());
                    return res;
                }
            
                @Override
                public void handleResponse(final HttpResponse res) throws Exception {
                    // we should see the set-cookie header coming back to us here...
                    Set<Cookie> cookies = extractSetCookies(res);
                    assert(cookies.size() == 1);
                    for (Cookie c : cookies) {
                        assertEquals(c.getName(), testName);
                        assertEquals(c.getValue(), testValue);
                    }
                }
            });

            // try to send a cookie through again, it should now be white-listed
            // since we sent a set-cookie during the prior test.
            conn.runTest(new RoundTripTest() {        
                @Override
                public HttpRequest createRequest() throws Exception {
                    final HttpRequest req = conn.createBaseRequest(testHost);
                    
                    CookieEncoder enc = new CookieEncoder(false);
                    enc.addCookie(testName, testValue);
                    req.setHeader(HttpHeaders.Names.COOKIE, enc.encode());
                    return req;
                }
            
                @Override
                public HttpResponse createResponse(final HttpRequest request, final Channel origin) throws Exception {
                    // now the cookie header should have come through...
                    assertTrue(request.getHeader(HttpHeaders.Names.COOKIE) != null);
                    Set<Cookie> cookies = extractCookies(request);
                    assertTrue(cookies.size() == 1);
                    for (Cookie c: cookies) {
                        assertEquals(c.getName(), testName);
                        assertEquals(c.getValue(), testValue);
                    }
                    
                    // just send a blank response 
                    final HttpResponse res = TestingUtils.createResponse("", origin.getConfig().getBufferFactory());
                    return res;
                }
            
                @Override
                public void handleResponse(final HttpResponse res) throws Exception {
                    // nothing to check here.
                }
            });

            // if we try to send it witha  different value, it should be clipped out.
            // on the way back, we'll change the value
            conn.runTest(new RoundTripTest() {        
                @Override
                public HttpRequest createRequest() throws Exception {
                    final HttpRequest req = conn.createBaseRequest(testHost);
                    
                    CookieEncoder enc = new CookieEncoder(false);
                    enc.addCookie(testName, testValue + "BAD");
                    req.setHeader(HttpHeaders.Names.COOKIE, enc.encode());
                    return req;
                }
            
                @Override
                public HttpResponse createResponse(final HttpRequest request, final Channel origin) throws Exception {
                    // no cookie should have been sent.
                    assertTrue(request.getHeader(HttpHeaders.Names.COOKIE) == null);
                    
                    // now change the cookie's value...
                    final HttpResponse res = TestingUtils.createResponse("", origin.getConfig().getBufferFactory());
                    CookieEncoder enc = new CookieEncoder(true);
                    enc.addCookie(testName, testValue2);
                    res.setHeader(HttpHeaders.Names.SET_COOKIE, enc.encode());
                    return res;
                }
            
                @Override
                public void handleResponse(final HttpResponse res) throws Exception {
                    // we should see the set-cookie header coming back to us here...
                    Set<Cookie> cookies = extractSetCookies(res);
                    assert(cookies.size() == 1);
                    for (Cookie c : cookies) {
                        assertEquals(c.getName(), testName);
                        assertEquals(c.getValue(), testValue2);
                    }
                }
            });

            // try to send a cookie through with original value, it should be clipped out.
            conn.runTest(new RoundTripTest() {        
                @Override
                public HttpRequest createRequest() throws Exception {
                    final HttpRequest req = conn.createBaseRequest(testHost);
                    
                    CookieEncoder enc = new CookieEncoder(false);
                    enc.addCookie(testName, testValue);
                    req.setHeader(HttpHeaders.Names.COOKIE, enc.encode());
                    return req;
                }
            
                @Override
                public HttpResponse createResponse(final HttpRequest request, final Channel origin) throws Exception {
                    // here we should see no cookie header coming through, it will have been clipped out entirely...
                    assertTrue(request.getHeader(HttpHeaders.Names.COOKIE) == null);
                    
                    final HttpResponse res = TestingUtils.createResponse("", origin.getConfig().getBufferFactory());
                    return res;
                }
            
                @Override
                public void handleResponse(final HttpResponse res) throws Exception {
                }
            });

            // with the new value it should go through fine.
            conn.runTest(new RoundTripTest() {        
                @Override
                public HttpRequest createRequest() throws Exception {
                    final HttpRequest req = conn.createBaseRequest(testHost);
                    
                    CookieEncoder enc = new CookieEncoder(false);
                    enc.addCookie(testName, testValue2);
                    req.setHeader(HttpHeaders.Names.COOKIE, enc.encode());
                    return req;
                }
            
                @Override
                public HttpResponse createResponse(final HttpRequest request, final Channel origin) throws Exception {
                    assertTrue(request.getHeader(HttpHeaders.Names.COOKIE) != null);
                    Set<Cookie> cookies = extractCookies(request);
                    assertTrue(cookies.size() == 1);
                    for (Cookie c: cookies) {
                        assertEquals(c.getName(), testName);
                        assertEquals(c.getValue(), testValue2);
                    }
                    
                    // just send a blank response 
                    final HttpResponse res = TestingUtils.createResponse("", origin.getConfig().getBufferFactory());
                    return res;
                }
            
                @Override
                public void handleResponse(final HttpResponse res) throws Exception {
                }
            });


            // conn.runTest(new RoundTripTest() {        
            //     @Override
            //     public HttpRequest createRequest() throws Exception {
            //         final HttpRequest req = conn.createBaseRequest(testHost);
            //         return req;
            //     }
            // 
            //     @Override
            //     public HttpResponse createResponse(final HttpRequest request, final Channel origin) throws Exception {
            //         final HttpResponse res = TestingUtils.createResponse("", origin.getConfig().getBufferFactory());
            //         return res;
            //     }
            // 
            //     @Override
            //     public void handleResponse(final HttpResponse res) throws Exception {
            //     }
            // });

        }
        finally {
            conn.teardown();
        }
    }
}
