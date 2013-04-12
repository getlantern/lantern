package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.lantern.TestingUtils.createSetCookie;

import java.net.URI;

import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.DefaultHttpRequest;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpVersion;
import org.junit.Ignore;
import org.junit.Test;
import org.lantern.cookie.CookieFilter;
import org.lantern.cookie.CookieUtils;
import org.lantern.cookie.StoredCookie;

@Ignore
public class CookieUtilsTest {

    /**
     * tests cookie rejection policy
     */
    @Test
    public void testRFC6265StoragePolicy() throws Exception {
        
        // header value, request uri
        String acceptTrue[][] = new String[][] {
            {"name=value", "http://www.example.org/"},
            {"name=value; path=/foo;", "http://www.example.org/"},
            {"name=value; domain=example.org;", "http://www.example.org/"},
            {"name=value; domain=.example.org;", "http://www.example.org/"},
            {"name=value; domain=www.example.org;", "http://www.example.org/"},
            {"name=value; domain=.www.example.org;", "http://www.example.org/"},
            {"name=value", "http://co.uk/"},
            {"name=value; domain=co.uk", "http://co.uk/"},
            {"name=value; domain=.co.uk", "http://co.uk/"},
            {"name=value", "http://127.0.0.1/"},
            {"name=value; domain=127.0.0.1", "http://127.0.0.1/"}
        };
        for (String []test : acceptTrue) {
            final Cookie cookie = createSetCookie(test[0], test[1]);
            final HttpRequest req = new DefaultHttpRequest(HttpVersion.HTTP_1_1, HttpMethod.GET, test[1]);
            final CookieFilter policy = new CookieUtils.RFC6265SetCookieFilter(req);
            assertTrue(test[0] + ',' + test[1], policy.accepts(cookie));
        }

        String acceptFalse[][] = new String[][]{
            {"name=value; domain=abc.example.org;", "http://www.example.org"},
            {"name=value; domain=abc.www.example.org;", "http://www.example.org"},
            {"name=value; domain=ww.example.org;", "http://www.example.org/"},
            {"name=value; domain=org;", "http://www.example.org"},
            {"name=value; domain=.org;", "http://www.example.org"},
            {"name=value; domain=facebook.com;", "http://www.example.org/"},
            {"name=value; domain=.0.0.1;", "http://127.0.0.1/"},
        };
        for (String []test : acceptFalse) {
            final Cookie cookie = createSetCookie(test[0], test[1]);
            final HttpRequest req = new DefaultHttpRequest(HttpVersion.HTTP_1_1, HttpMethod.GET, test[1]);
            final CookieFilter policy = new CookieUtils.RFC6265SetCookieFilter(req);
            assertFalse(test[0] + ',' + test[1], policy.accepts(cookie));
        }
    }
    

    /** 
     * tests rules for whether a cookie can/should be 
     * sent to a given request uri based on domain.
     */ 
    @Test 
    public void testCanBeSent() throws Exception {

        StoredCookie cookie;

        
        /* 
         * domain matching
         */
        
        
        cookie = new StoredCookie("name", "value");
        cookie.setDomain("bar.example.org");
        cookie.setPath("/");
        cookie.setSecure(false);

        // when the host only flag is set, only the exact 
        // domain name can have the cookie. 
        cookie.setHostOnly(true);
        // this exact match will pass
        assertTrue(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/")));
        // all these non-exact matches will fail
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://foo.bar.example.org/")));
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://example.org/")));
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://www.example.org/")));
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://badbar.example.org/")));
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://elsewhere.com/")));
        
        // all else being equals, if host only is false, exact matching
        // is not required, only 'domain matching'
        cookie.setHostOnly(false);
        // these domain match
        assertTrue(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/")));
        assertTrue(CookieUtils.canBeSent(cookie, new URI("http://foo.bar.example.org/")));
        // these should still fail.
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://example.org/")));
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://www.example.org/")));
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://badbar.example.org/")));
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://elsewhere.com/")));

        /*
         * path matching 
         */
        cookie = new StoredCookie("name", "value");
        cookie.setHostOnly(true);
        cookie.setDomain("bar.example.org");
        cookie.setSecure(false);
        cookie.setPath("/foo");

        assertTrue(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/foo")));
        assertTrue(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/foo/")));
        assertTrue(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/foo/bar/baz")));
        // these do not path match
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org")));
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/quux")));
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/foobad")));
        
        // exact prefix is required, so this means something slightly different
        cookie.setPath("/foo/");
        assertTrue(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/foo/")));
        assertTrue(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/foo/bar/baz")));
        // these do not path match
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/foo")));
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org")));
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/quux")));
        assertFalse(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/foobad")));
        
        /*
         * secure flag
         */
         cookie = new StoredCookie("name", "value");
         cookie.setHostOnly(true);
         cookie.setDomain("bar.example.org");
         cookie.setPath("/");
         cookie.setSecure(false);
         
         assertTrue(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/")));
    
         // currently we always say false when the secure flag has 
         // somehow been set and it is visible to us because we 
         // are never dealing with the contents of a secure end-to-end
         // communication (those are invisible to us)
         cookie.setSecure(true); 
         assertFalse(CookieUtils.canBeSent(cookie, new URI("http://bar.example.org/")));
    }

    /**
     * test cookie domain matching rules
     */
    @Test
    public void testDomainMatches() {
        // cookie domain, hostname
        final String domainMatchesTrue[][] = new String[][]{
            {"example.org", "example.org"},
            {"example.org", "foo.example.org"},
            {"example.org", "foo.bar.example.org"},
            {"127.0.0.1", "127.0.0.1"}
        };
        for (String[] test : domainMatchesTrue) {
            assertTrue(test[0] + "," + test[1], CookieUtils.domainMatches(test[0], test[1]));
        }

        // cookie domain, hostname
        final String domainMatchesFalse[][] = new String[][]{
            {"evil.com", "google.com"},
            {"malicious.google.com", "google.com"},
            {"malicious.google.com", "docs.google.com"},
            {"google.com", "badgoogle.com"},
            {"docs.google.com", "badocs.google.com"},
            {"0.0.1", "127.0.0.1"},
        };
        for (String[] test : domainMatchesFalse) {
            assertFalse(test[0] + "," + test[1], CookieUtils.domainMatches(test[0], test[1]));
        }
    }

    /**
     * tests host canonicalization.
     */ 
    @Test
    public void testCanonicalizeHost() {
        final String tests[][] = new String[][]{
            {"www.example.org", "www.example.org"},
            {"酒.biz", "xn--jj4a.biz"},
            {"酒\u3002biz", "xn--jj4a.biz"},
            {"酒\uFF0Ebiz", "xn--jj4a.biz"},
            {"酒\uFF61biz", "xn--jj4a.biz"},
            {"東京.jp", "xn--1lqs71d.jp"},
            {"foö.bar.org", "xn--fo-gka.bar.org"},
            {"\u0627\u06CC\u0643\u0648\u0645.edu", "xn--mgb0dgl27d.edu"},
        };
        
        for (String[] test : tests) {
            assertEquals(test[1], CookieUtils.canonicalizeHost(test[0]));
        }
    }
    
    /**
     * tests cookie path matching implementation.
     */
    @Test
    public void testPathMatches() {
        // cookie path, request path
        final String pathMatchTrue[][] = new String[][]{
            {"/", "/foo"},
            {"/foo", "/foo"},
            {"/foo", "/foo/bar"},
            {"/foo/", "/foo/bar"},
            {"/foo/bar", "/foo/bar"},
            {"/foo/bar", "/foo/bar/baz"},
            {"/foo/bar/", "/foo/bar/baz"}
        };
        for (String[] test: pathMatchTrue) {
            assertTrue(test[0] + "," + test[1], CookieUtils.pathMatches(test[0], test[1]));
        }

        // cookie path, request path
        final String pathMatchFalse[][] = new String[][]{
            {"/foo/", ""},
            {"/foo/", "/foo"},
            {"/bar/", "/foo/bar"},
            {"/foo", "/fooledyou"},
            {"/foo/bar", "/foo/barredyou"},        
        };
        for (String []test: pathMatchFalse) {
            assertFalse(test[0] + "," + test[1], CookieUtils.pathMatches(test[0], test[1]));
        }

    }
    
    /**
     * smoke test detection of "public suffixes" like com, net 
     * etc which are illegal to set wildcard cookies on.
     */
    @Test
    public void testIsPublicSuffix() {
        // not comprehensive, just smoke.
        
        final String publicTrue[] = new String[]{
            "com", "org", "net", "co.uk", "sh.cn", "bristol.museum", "sør-fron.no",
            "co\u002Euk", "co\u3002uk", "sh\uFF0Ecn", "bristol\uFF61museum" // alt 'full stop'
        };
        for (String test : publicTrue) {
            assertTrue(test, CookieUtils.isPublicSuffix(test));
        }
        
        final String publicFalse[] = new String[]{
            "foo.com", "example.org", "slashdot.org"
        };        
        for (String test : publicFalse) {
            assertFalse(test, CookieUtils.isPublicSuffix(test));
        }
    }
    
    /**
     * tests simple cookie domain attribute 
     * normalization.
     */
    @Test
    public void testNormalizedSetCookieDomain() throws Exception {
        // input, normalized input
        final String tests[][] = new String[][]{
            {null, null},
            {"", null},
            {".example.org", "example.org"},
            {"example.org", "example.org"},
            {".fOO.ExAmPLE.org", "foo.example.org"},
            {"fOO.ExAmPLE.org", "foo.example.org"}
        };

        for (String [] test : tests) {
            assertEquals(test[1], CookieUtils.normalizedSetCookieDomain(test[0]));
        }
    }
    
    /**
     * tests simple cookie path attribute normalization
     */
    @Test
    public void testNormalizedSetCookiePath() throws Exception {
        // path, uri, result
        final String tests[][] = new String[][]{
            {null, "http://foo.bar.org/foo/bar", "/foo"},
            {"", "http://foo.bar.org/foo/bar", "/foo"},
            {"fliz", "http://foo.bar.org/foo/bar", "/foo"},
            {"/wow", "http://foo.bar.org/foo/bar", "/wow"},
            {"/wow/wee", "http://foo.bar.org/foo/bar", "/wow/wee"},
            {"/wow/wee/", "http://foo.bar.org/foo/bar", "/wow/wee/"},
        };
     
        for (String [] test : tests) {
            URI uri = CookieUtils.makeSafeURI(test[1]);
            assertEquals(test[2], CookieUtils.normalizedSetCookiePath(test[0], uri));
        }
    }
    
    /**
     * tests calculation of default cookie paths 
     * based on request url.
     */
    @Test
    public void testDefaultSetCookiePath() throws Exception {
        
        // uri, result
        final String tests[][] = new String[][]{
            {"http://foo.bar.org", "/"},
            {"http://foo.bar.org/", "/"},
            {"http://foo.bar.org/foo", "/"},
            {"http://foo.bar.org/foo/", "/foo"},
            {"http://foo.bar.org/foo/bar", "/foo"},
            {"http://foo.bar.org/foo/bar/", "/foo/bar"},
            {"https://flöke:flöp@foö.bar.org:9191/qöux/bzo/baz?zbfö=zboe&foo#glöp", "/qöux/bzo"}        
        };
        
        
        for (String [] test : tests) {
            URI uri = CookieUtils.makeSafeURI(test[0]);
            assertEquals(test[1], CookieUtils.defaultSetCookiePath(uri));
        }
        
    }
    
    /**
     * tests construction of uris with non-ascii 
     * hostnames.
     */
    @Test
    public void testSafeURI() throws Exception {
        URI uri;
        
        String uriString = "http://foö.bar.org/quux";
        
        // first, assert the problem exists, otherwise we 
        // may not need this rigamarole. Hostname with 
        // non-ascii characters will yield a null host.
        uri = new URI("http://foö.bar.org/quux");
        assertTrue(uri.getHost() == null);

        // using makeSafeURI we should get the A-Name version 
        // of the hostname.
        uri = CookieUtils.makeSafeURI(uriString);
        assertTrue(uri.getHost().equals("xn--fo-gka.bar.org"));
        assertTrue(uri.getPath().equals("/quux"));
        
        // additional non-ascii characters in the url 
        // outside the hostname should be the same.
        uriString = "http://foö.bar.org/qöux";
        uri = CookieUtils.makeSafeURI(uriString);
        assertTrue(uri.getHost().equals("xn--fo-gka.bar.org"));
        assertTrue(uri.getPath().equals("/qöux"));
        
        // preserves other junks, just modifies host
        uriString = "https://flöke:flöp@foö.bar.org:9191/qöux?zbfö=zboe&foo#glöp";
        uri = CookieUtils.makeSafeURI(uriString);
        assertTrue(uri.getHost().equals("xn--fo-gka.bar.org"));
        assertTrue(uri.getPath().equals("/qöux"));
        assertTrue(uri.getUserInfo().equals("flöke:flöp"));
        assertTrue(uri.getScheme().equals("https"));
        assertTrue(uri.getPort() == 9191);
        assertTrue(uri.getQuery().equals("zbfö=zboe&foo"));
        assertTrue(uri.getFragment().equals("glöp"));
        assertTrue(uri.toString().equals("https://flöke:flöp@xn--fo-gka.bar.org:9191/qöux?zbfö=zboe&foo#glöp"));

        // should be idempotent
        uri = CookieUtils.makeSafeURI(uri.toString());
        assertTrue(uri.getHost().equals("xn--fo-gka.bar.org"));
        assertTrue(uri.getPath().equals("/qöux"));
        assertTrue(uri.getUserInfo().equals("flöke:flöp"));
        assertTrue(uri.getScheme().equals("https"));
        assertTrue(uri.getPort() == 9191);
        assertTrue(uri.getQuery().equals("zbfö=zboe&foo"));
        assertTrue(uri.getFragment().equals("glöp"));
        assertTrue(uri.toString().equals("https://flöke:flöp@xn--fo-gka.bar.org:9191/qöux?zbfö=zboe&foo#glöp"));

    }
}