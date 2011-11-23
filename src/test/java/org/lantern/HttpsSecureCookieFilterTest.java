package org.lantern; 

import java.util.ArrayList;
import java.util.List;
import static org.junit.Assert.*;
import org.junit.Test;
import org.jboss.netty.handler.codec.http.DefaultCookie;
import org.jboss.netty.handler.codec.http.DefaultHttpRequest;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpVersion;
import org.lantern.cookie.CookieFilter;
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
        
        for (final String uri : filterUri) {
            CookieFilter f = new HttpsSecureCookieFilter(_makeGetRequest(uri));
            assertFalse(f.accepts(new DefaultCookie("foo", "0")));
        }

        for (final String uri : nofilterUri) {
            CookieFilter f = new HttpsSecureCookieFilter(_makeGetRequest(uri));
            assertTrue(f.accepts(new DefaultCookie("foo", "0")));
        }
        
    }

    private HttpRequest _makeGetRequest(final String uri) {
        return new DefaultHttpRequest(HttpVersion.HTTP_1_1, HttpMethod.GET, uri);
    }

}