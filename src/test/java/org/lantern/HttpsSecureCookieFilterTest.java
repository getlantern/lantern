package org.lantern; 

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.lantern.TestingUtils.createGetRequest;

import java.util.ArrayList;
import java.util.List;

import org.jboss.netty.handler.codec.http.DefaultCookie;
import org.junit.Test;
import org.lantern.cookie.CookieFilter;
import org.lantern.httpseverywhere.HttpsEverywhere;
import org.lantern.httpseverywhere.HttpsSecureCookieFilter;
import org.lantern.httpseverywhere.HttpsSecureCookieRule;

public class HttpsSecureCookieFilterTest {
    
    @Test
    public void testBasicFilter() {
        List<HttpsSecureCookieRule> testRules = new ArrayList<HttpsSecureCookieRule>();
        testRules.add(new HttpsSecureCookieRule("", "foo")); // exactly foo
        testRules.add(new HttpsSecureCookieRule("", "bar.*")); // starts with bar
        testRules.add(new HttpsSecureCookieRule("", ".*qup")); // ends with qup
        testRules.add(new HttpsSecureCookieRule("", ".*baz.*")); // contains baz
        
        CookieFilter f = new HttpsSecureCookieFilter(testRules);
        
        assertFalse(f.accepts(new DefaultCookie("foo", "0")));
        assertTrue(f.accepts(new DefaultCookie("foox", "0")));
        assertTrue(f.accepts(new DefaultCookie("xfoo", "0")));
        assertTrue(f.accepts(new DefaultCookie("xfoox", "0")));
        
        assertFalse(f.accepts(new DefaultCookie("bar", "0")));
        assertFalse(f.accepts(new DefaultCookie("barx", "0")));
        assertTrue(f.accepts(new DefaultCookie("xbar", "0")));
        assertTrue(f.accepts(new DefaultCookie("xbarx", "0")));

        assertFalse(f.accepts(new DefaultCookie("qup", "0")));
        assertFalse(f.accepts(new DefaultCookie("xqup", "0")));
        assertTrue(f.accepts(new DefaultCookie("qupx", "0")));
        assertTrue(f.accepts(new DefaultCookie("xqupx", "0")));
        
        assertFalse(f.accepts(new DefaultCookie("baz", "0")));
        assertFalse(f.accepts(new DefaultCookie("xbaz", "0")));
        assertFalse(f.accepts(new DefaultCookie("bazx", "0")));
        assertFalse(f.accepts(new DefaultCookie("xbazx", "0")));
    
        assertTrue(f.accepts(new DefaultCookie("dabba", "0")));
    }
    
    @Test
    public void testConfiguredRules() {
        final String filterUri[] = {"http://twitter.com", "http://chupa.twitter.com"};
        final String nofilterUri[] = {"http://example.com", };
        
        final HttpsEverywhere he = new HttpsEverywhere();
        for (final String uri : filterUri) {
            CookieFilter f = new HttpsSecureCookieFilter(createGetRequest(uri), he);
            assertFalse(f.accepts(new DefaultCookie("foo", "0")));
        }

        for (final String uri : nofilterUri) {
            CookieFilter f = new HttpsSecureCookieFilter(createGetRequest(uri), he);
            assertTrue(f.accepts(new DefaultCookie("foo", "0")));
        }
        
    }

}