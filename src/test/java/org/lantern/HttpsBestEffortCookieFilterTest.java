package org.lantern; 

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.lantern.TestingUtils.createGetRequest;

import java.util.ArrayList;
import java.util.List;

import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.DefaultCookie;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.junit.Test;
import org.lantern.cookie.CookieFilter;
import org.lantern.cookie.InMemoryCookieTracker;
import org.lantern.httpseverywhere.HttpsBestEffortCookieFilter;
import org.lantern.httpseverywhere.HttpsEverywhere;
import org.lantern.httpseverywhere.HttpsSecureCookieFilter;
import org.lantern.httpseverywhere.HttpsSecureCookieRule;

public class HttpsBestEffortCookieFilterTest {
    
    /**
     * just tests the basic schema of the best effort 
     * filter's behavior with respect to whitelist/blacklist.
     */
    @Test
    public void testBasicFiltering() {
        final CookieFilter cf = new HttpsBestEffortCookieFilter(
            // whitelist : if this accepts, the filter accepts, 
            // if it rejects, the filter defers to the blacklist
            // in this case cookies named foo are whitelisted
            new CookieFilter() {
                @Override
                public boolean accepts(Cookie c) {
                    return c.getName().equals("foo");
                }
            },
            
            // blacklist : if not whitelisted, the filter accepts
            // iff the blacklist accepts.
            // in this case cookies named "bar" are blacklisted.
            new CookieFilter() {
                @Override
                public boolean accepts(Cookie c) {
                    return !c.getName().equals("bar");
                }
            }
        
        );
        
        assertTrue(cf.accepts(new DefaultCookie("foo", ""))); // whitelisted
        assertFalse(cf.accepts(new DefaultCookie("bar", ""))); // blacklisted
        assertTrue(cf.accepts(new DefaultCookie("quux", ""))); // neither
        
    }
    
    /** 
     * tests whitelisting a cookie affects the best effort cookie
     * filter in the expected way. 
     */ 
    @Test
    public void testTrackerWhitelist() throws Exception {
        final HttpRequest req = createGetRequest("http://www.example.com/");
    
        final InMemoryCookieTracker tracker = new InMemoryCookieTracker(); 

        final CookieFilter cf = new HttpsBestEffortCookieFilter(
            tracker.asOutboundCookieFilter(req, false),
            new CookieFilter() {
                @Override
                public boolean accepts(Cookie c) {
                    return false;
                }
            }
        );
        
        assertFalse(cf.accepts(new DefaultCookie("foo", "")));
        assertFalse(cf.accepts(new DefaultCookie("bar", "")));
        
        // whitelist a cookie
        tracker.setCookie(new DefaultCookie("foo", ""), req);
        
        // should now be accepted
        assertTrue(cf.accepts(new DefaultCookie("foo", "")));
        assertFalse(cf.accepts(new DefaultCookie("bar", "")));
    }
    
    /**
     * tests interaction of whitelisting and a set of 
     * secure cookie rules.
     */ 
    @Test
    public void testFakeFules() throws Exception {
        final List<HttpsSecureCookieRule> testRules = new ArrayList<HttpsSecureCookieRule>();
        testRules.add(new HttpsSecureCookieRule("", "bar.*")); // starts with bar
        final CookieFilter secureCookieFilter = new HttpsSecureCookieFilter(testRules);

        final HttpRequest req = createGetRequest("http://www.example.com/");

        final InMemoryCookieTracker tracker = new InMemoryCookieTracker(); 

        // this filter will reject anything starting with "bar" 
        // unless it has been whitelisted in the tracker.
        final CookieFilter cf = new HttpsBestEffortCookieFilter(
            tracker.asOutboundCookieFilter(req, false),
            secureCookieFilter
        );
        
        assertTrue(cf.accepts(new DefaultCookie("foo", "")));
        assertFalse(cf.accepts(new DefaultCookie("bar", "")));
        assertFalse(cf.accepts(new DefaultCookie("barn", "")));
        assertFalse(cf.accepts(new DefaultCookie("barnyard", "")));
        
        // whitelist a cookie
        tracker.setCookie(new DefaultCookie("bar", ""), req);

        assertTrue(cf.accepts(new DefaultCookie("foo", "")));
        assertTrue(cf.accepts(new DefaultCookie("bar", "")));
        assertFalse(cf.accepts(new DefaultCookie("barn", "")));
        assertFalse(cf.accepts(new DefaultCookie("barnyard", "")));

        // whitelist a cookie
        tracker.setCookie(new DefaultCookie("barnyard", ""), req);

        assertTrue(cf.accepts(new DefaultCookie("foo", "")));
        assertTrue(cf.accepts(new DefaultCookie("bar", "")));
        assertFalse(cf.accepts(new DefaultCookie("barn", "")));
        assertTrue(cf.accepts(new DefaultCookie("barnyard", "")));
    }
    
    /**
     * tests interaction of whitelisting with the globally 
     * configured httpseverywhere securecookie rules. 
     */ 
    @Test 
    public void testConfiguredRules() throws Exception {

        final InMemoryCookieTracker tracker = new InMemoryCookieTracker(); 

        final HttpsEverywhere he = new HttpsEverywhere();
        final String filteredUris[] = {"http://twitter.com/", "http://foo.twitter.com/"};    
        for (final String uri : filteredUris) {
            final HttpRequest req = createGetRequest(uri);

            final CookieFilter secureCookieFilter = new HttpsSecureCookieFilter(req, he);

            final CookieFilter cf = new HttpsBestEffortCookieFilter(
                tracker.asOutboundCookieFilter(req, false),
                secureCookieFilter
            );
            
            assertFalse(cf.accepts(new DefaultCookie("foo", "")));
            
            tracker.setCookie(new DefaultCookie("foo", ""), req);
            
            assertTrue(cf.accepts(new DefaultCookie("foo", "")));
        }
        

        final String unfilteredUris[] = {"http://www.example.org/", };
        for (final String uri : unfilteredUris) {
            final HttpRequest req = createGetRequest(uri);
            
            final CookieFilter secureCookieFilter = 
                new HttpsSecureCookieFilter(req, he);
            final CookieFilter cf = new HttpsBestEffortCookieFilter(
                tracker.asOutboundCookieFilter(req, false),
                secureCookieFilter
            );
            
            assertTrue(cf.accepts(new DefaultCookie("foo", "")));
            
            tracker.setCookie(new DefaultCookie("foo", ""), req);
            
            assertTrue(cf.accepts(new DefaultCookie("foo", "")));
        }

    }
    
    
}