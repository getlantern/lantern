package org.lantern;

import java.net.URI;
import java.util.Collections;
import java.util.Set;
import java.util.ArrayList;
import java.util.List;
import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.CookieDecoder;
import org.jboss.netty.handler.codec.http.DefaultHttpRequest; 
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpVersion;
import static org.junit.Assert.*;

import org.junit.Ignore;
import org.junit.Test;
import org.lantern.cookie.InMemoryCookieTracker;
import static org.lantern.TestingUtils.*;

@Ignore
public class InMemoryCookieTrackerTest {
    
    @Test
    public void testWouldSendCookieDefaults() throws Exception {
        // set up tracker with default policy
        final InMemoryCookieTracker tracker = new InMemoryCookieTracker();
        
        // simulate a set-cookie from example.com/baz of foo=bar
        // no specification of domain or path (use defaults)
        // this should have a default path of /baz
        final String url = "http://example.com/baz/quux";
        final Cookie setCookie = createDefaultCookie("foo=bar");
        final HttpRequest req = createGetRequest(url);
        tracker.setCookie(setCookie, req);
        
        // create an cookie that would potentially be sent by the browser
        // with the same name and value.
        final Cookie outCookie = createDefaultCookie("foo=bar");

        // should be sent to the identical domain it came from only
        assertTrue(tracker.wouldSendCookie(outCookie, new URI(url)));
        // none of these should work
        assertFalse(tracker.wouldSendCookie(outCookie, new URI("http://www.example.com/baz")));
        assertFalse(tracker.wouldSendCookie(outCookie, new URI("http://xample.com/baz")));
        assertFalse(tracker.wouldSendCookie(outCookie, new URI("http://com/baz")));
        
        // path should default to the request path, anything under it should be fine
        assertTrue(tracker.wouldSendCookie(outCookie, new URI("http://example.com/baz/")));
        assertTrue(tracker.wouldSendCookie(outCookie, new URI("http://example.com/baz/quux")));
        assertTrue(tracker.wouldSendCookie(outCookie, new URI("http://example.com/baz/quux/blurn")));
        // anything else should not.
        assertFalse(tracker.wouldSendCookie(outCookie, new URI("http://example.com/bazbad")));
        assertFalse(tracker.wouldSendCookie(outCookie, new URI("http://example.com/")));
        assertFalse(tracker.wouldSendCookie(outCookie, new URI("http://example.com/foo")));

    }
    
    @Test
    public void testWouldSendCookieCheckValue() throws Exception {
        // set up tracker with default policy
        final InMemoryCookieTracker tracker = new InMemoryCookieTracker();
        
        // simulate a set-cookie from example.com/baz of foo=bar
        // no specification of domain or path (use defaults)
        // this should have a default path of /baz
        final String url = "http://example.com/baz/quux";
        final Cookie setCookie = createDefaultCookie("foo=bar");
        final HttpRequest req = createGetRequest(url);
        tracker.setCookie(setCookie, req);
        
        // create an cookie that would potentially be sent by the browser
        // with the same name and value. 
        final Cookie sameValCookie = createDefaultCookie("foo=bar");
        // create another with the same name but a different value 
        final Cookie diffValCookie = createDefaultCookie("foo=quux");

        // the one with the same value should still be sendable when value checking is enabled
        assertTrue(tracker.wouldSendCookie(sameValCookie, new URI("http://example.com/baz/"), true));
        assertTrue(tracker.wouldSendCookie(sameValCookie, new URI("http://example.com/baz/quux"), true));
        assertTrue(tracker.wouldSendCookie(sameValCookie, new URI("http://example.com/baz/quux/blurn"), true));
        // also fine when disabled...
        assertTrue(tracker.wouldSendCookie(sameValCookie, new URI("http://example.com/baz/"), false));
        assertTrue(tracker.wouldSendCookie(sameValCookie, new URI("http://example.com/baz/quux"), false));
        assertTrue(tracker.wouldSendCookie(sameValCookie, new URI("http://example.com/baz/quux/blurn"), false));


        // the one with the different value should not be sendable when value checking enabled
        assertFalse(tracker.wouldSendCookie(diffValCookie, new URI("http://example.com/baz/"), true));
        assertFalse(tracker.wouldSendCookie(diffValCookie, new URI("http://example.com/baz/quux"), true));
        assertFalse(tracker.wouldSendCookie(diffValCookie, new URI("http://example.com/baz/quux/blurn"), true));

        // but it should be fine with value checking off
        assertTrue(tracker.wouldSendCookie(diffValCookie, new URI("http://example.com/baz/"), false));
        assertTrue(tracker.wouldSendCookie(diffValCookie, new URI("http://example.com/baz/quux"), false));
        assertTrue(tracker.wouldSendCookie(diffValCookie, new URI("http://example.com/baz/quux/blurn"), false));

    }
    
    @Test 
    public void testSimilarAttributes() throws Exception {
        final InMemoryCookieTracker tracker = new InMemoryCookieTracker();

        // create and set 4 similar cookies.  They should all wind up in the 
        // store and behave differently.
        Cookie setCookie1 = createDefaultCookie("foo=1; domain=example.com");
        Cookie setCookie2 = createDefaultCookie("foo=2; domain=example.com; path=/foo;");
        Cookie setCookie3 = createDefaultCookie("foo=3; domain=foo.example.com");
        Cookie setCookie4 = createDefaultCookie("foo=4; domain=bar.example.com");
        
        tracker.setCookie(setCookie1, createGetRequest("http://example.com/"));
        tracker.setCookie(setCookie2, createGetRequest("http://example.com/foo"));
        tracker.setCookie(setCookie3, createGetRequest("http://foo.example.com/"));
        tracker.setCookie(setCookie4, createGetRequest("http://bar.example.com/"));
        

        Cookie cookie1 = createDefaultCookie("foo=1");
        Cookie cookie2 = createDefaultCookie("foo=2");
        Cookie cookie3 = createDefaultCookie("foo=3");
        Cookie cookie4 = createDefaultCookie("foo=4");

        // check that the appropriate cookies are present and go 
        // to the expected locaations only.  In all cases, value 
        // checking is enabled to differentiate the cookies.
        
        URI uri;
        
        uri = new URI("http://example.com/");
        assertTrue(tracker.wouldSendCookie(cookie1, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie2, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));

        uri = new URI("http://example.com/foo");
        assertTrue(tracker.wouldSendCookie(cookie1, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie2, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));
    
        uri = new URI("http://www.example.com/");
        assertTrue(tracker.wouldSendCookie(cookie1, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie2, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));

        uri = new URI("http://www.example.com/foo");
        assertTrue(tracker.wouldSendCookie(cookie1, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie2, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));

        uri = new URI("http://www.example.com/foo/bar");
        assertTrue(tracker.wouldSendCookie(cookie1, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie2, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));

        uri = new URI("http://foo.example.com/");
        assertTrue(tracker.wouldSendCookie(cookie1, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie2, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));

        uri = new URI("http://foo.example.com/foo");
        assertTrue(tracker.wouldSendCookie(cookie1, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie2, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));

        uri = new URI("http://bar.example.com/foo");
        assertTrue(tracker.wouldSendCookie(cookie1, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie2, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie3, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie4, uri, true));

        uri = new URI("http://badexample.com/foo");
        assertFalse(tracker.wouldSendCookie(cookie1, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie2, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));


    }

    @Test
    public void testCookieOverwrite() throws Exception {
        // these should overwrite each other when set on http://www.example.com/foo/
        Cookie setCookie0 = createDefaultCookie("foo=0");
        Cookie setCookie1 = createDefaultCookie("foo=1; domain=www.example.com;");
        Cookie setCookie2 = createDefaultCookie("foo=2; domain=www.example.com; path=/foo;");
        // these should not
        Cookie setCookie3 = createDefaultCookie("foo=3; domain=www.example.com; path=/;");
        Cookie setCookie4 = createDefaultCookie("foo=4; domain=example.com;");

        Cookie cookie0 = createDefaultCookie("foo=0");
        Cookie cookie1 = createDefaultCookie("foo=1");
        Cookie cookie2 = createDefaultCookie("foo=2");
        Cookie cookie3 = createDefaultCookie("foo=3");
        Cookie cookie4 = createDefaultCookie("foo=4");
        
        final InMemoryCookieTracker tracker = new InMemoryCookieTracker();
        
        URI uri = new URI("http://www.example.com/foo/");
        HttpRequest req = createGetRequest("http://www.example.com/foo/");
        
        // initially none of the cookies should be sendable
        assertFalse(tracker.wouldSendCookie(cookie0, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie1, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie2, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));
        
        // [0-2] should overwrite each other as they are set
        tracker.setCookie(setCookie0, req);
        assertTrue(tracker.wouldSendCookie(cookie0, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie1, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie2, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));

        tracker.setCookie(setCookie1, req);
        assertFalse(tracker.wouldSendCookie(cookie0, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie1, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie2, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));
        
        tracker.setCookie(setCookie2, req);
        assertFalse(tracker.wouldSendCookie(cookie0, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie1, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie2, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));
        
        tracker.setCookie(setCookie1, req);
        assertFalse(tracker.wouldSendCookie(cookie0, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie1, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie2, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));

        tracker.setCookie(setCookie0, req);
        assertTrue(tracker.wouldSendCookie(cookie0, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie1, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie2, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));

        // 3 and 4 should not overwrite, they're just independent cookies.

        tracker.setCookie(setCookie3, req);
        assertTrue(tracker.wouldSendCookie(cookie0, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie1, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie2, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie3, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie4, uri, true));

        tracker.setCookie(setCookie4, req);
        assertTrue(tracker.wouldSendCookie(cookie0, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie1, uri, true));
        assertFalse(tracker.wouldSendCookie(cookie2, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie3, uri, true));
        assertTrue(tracker.wouldSendCookie(cookie4, uri, true));


    }


    
    @Test
    public void testParallelSetCookie() throws Exception {
        // 
        // insert a bunch of cookies with the same name, domain, path
        // in parallel.  Make sure things look sane at the end of the 
        // day. 
        
        final InMemoryCookieTracker tracker = new InMemoryCookieTracker();
        final String requestUri = "http://example.com/";
        
        class CookieInserter extends Thread {
            
            boolean success = false; 
            
            @Override
            public void run() {
                // be slightly contentious on purpose, keep setting 
                // the cookie a few times.
                try {
                    for (int i = 0; i < 25; i++) {
                        Cookie myCookie = makeCookie();
                        HttpRequest req = createGetRequest(requestUri);
                        tracker.setCookie(myCookie, req);
                    }
                    success = true;
                }
                catch (Exception e) {
                    success = false;
                }            
            }
            
            public boolean succeeded() {
                return success;
            }
            
            public Cookie makeCookie() throws Exception {
                return createDefaultCookie("foo=" + getId());
            }
        }
        
        // create a bunch of cookie inserting threads.
        int ninserters = 100;
        List<CookieInserter> inserters = new ArrayList<CookieInserter>();
        for (int i = 0; i < ninserters; i++) {
            inserters.add(new CookieInserter());
        }
        Collections.shuffle(inserters);
        // start all the inserters
        for (CookieInserter ci : inserters) {
            ci.start();
        }
        // wait for all to complete
        for (CookieInserter ci : inserters) {
            ci.join();
        }
        
        // they all should have been able to perform inserts 
        // without encountering an error. 
        for (CookieInserter ci : inserters) {
            assertTrue(ci.succeeded());
        }
        
        // without value matching, every inserter's cookie should be sendable
        for (CookieInserter ci : inserters) {
            Cookie cookie = ci.makeCookie();
            assertTrue(tracker.wouldSendCookie(cookie, new URI(requestUri), false));
        }
        
        // with value matching, exactly one of the cookies should be sendable
        int numMatches = 0;
        for (CookieInserter ci : inserters) {
            Cookie cookie = ci.makeCookie();
            if (tracker.wouldSendCookie(cookie, new URI(requestUri), true)) {
                numMatches += 1;
            }
        }
        assertTrue(numMatches == 1);

    }

    @Test
    public void testParallelAccess() throws Exception {
        /* 
         * run a parallel set of simple cookie insertion / lookup tests, 
         * make sure all are able to complete successfully
         */
        final InMemoryCookieTracker tracker = new InMemoryCookieTracker();
        final String requestUriBase = "http://example.com/";

        class CookieTester extends Thread {
            
            boolean success = false;
            
            @Override
            public void run() {
                // be slightly contentious on purpose, keep setting 
                // the cookie a few times.
                try {
                    final String requestUri = requestUriBase + getId() + '/';
                    for (int i = 0; i < 100; i++) {
                        Cookie myCookie = makeCookie(i);
                        HttpRequest req = createGetRequest(requestUri);
                        tracker.setCookie(myCookie, req);
                        assertTrue(tracker.wouldSendCookie(myCookie, new URI(requestUri), true));
                        assertTrue(tracker.wouldSendCookie(myCookie, new URI(requestUri + "baz/blurn")));
                        assertFalse(tracker.wouldSendCookie(myCookie, new URI(requestUriBase)));
                        assertFalse(tracker.wouldSendCookie(makeCookie(i-1), new URI(requestUri), true));
                    }
                    success = true;
                }
                catch (Exception e) {
                    e.printStackTrace();
                    success = false;
                }            
            }

            public boolean succeeded() {
                return success;
            }

            public Cookie makeCookie(int value) throws Exception {
                return createDefaultCookie("cookie" + getId() + "=" + value);
            }
        }
        
        // create a bunch of cookie inserting threads.
        int ntesters = 50;
        List<CookieTester> testers = new ArrayList<CookieTester>();
        for (int i = 0; i < ntesters; i++) {
            testers.add(new CookieTester());
        }
        Collections.shuffle(testers);
        
        // start all the testers
        for (CookieTester ci : testers) {
            ci.start();
        }
        // wait for all to complete
        for (CookieTester ci : testers) {
            ci.join();
        }

        // they all should have been able to perform inserts 
        // without encountering an error. 
        for (CookieTester ci : testers) {
            assertTrue(ci.succeeded());
        }
    }
    
    
}