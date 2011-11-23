package org.lantern.cookie;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.concurrent.ConcurrentNavigableMap; 
import java.util.concurrent.ConcurrentSkipListMap;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import org.apache.commons.lang.builder.HashCodeBuilder;
import org.jboss.netty.handler.codec.http.Cookie; 
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 *
 * receives notification of Set-Cookies and stores legal Cookies 
 * in memory.  This is used as a dynamic whitelist for outbound
 * Cookie headers.
 * 
 * The intention is to be able to whitelist any upstream
 * Cookie has been "seen" in a legitimate insecure downstream
 * Set-Cookie.
 * 
 * All information about the cookies is discarded when the 
 * program exits.
 *
 */
public class InMemoryCookieTracker implements SetCookieObserver {

    private final Logger log = LoggerFactory.getLogger(getClass());

    // controls which cookies are allowed in.
    private CookieFilter.Factory setCookiePolicy; 
    
    private ConcurrentNavigableMap<CookieKey, CookieHolder> storedCookies;

    /**
     * construct with default cookie storage 
     * policy (RFC 6265)
     */
    public InMemoryCookieTracker() {
        this(new CookieFilter.Factory() {
                @Override
                public CookieFilter createCookieFilter(HttpRequest context) {
                    return new CookieUtils.RFC6265SetCookieFilter(context);
                }
            });
    }

    public InMemoryCookieTracker(CookieFilter setCookieFilter) {
        this(CookieUtils.dummyCookieFilterFactory(setCookieFilter));
    }
    
    /**
     * construct with a specific storage policy represented
     * by the given CookieFilter.  
     *
     * @param setCookiePolicy  A cookie is retained only 
     *        if setCookiePolicy.accepts(cookie) returns true.
     */ 
    public InMemoryCookieTracker(CookieFilter.Factory setCookiePolicy) {
        storedCookies = new ConcurrentSkipListMap<CookieKey, CookieHolder>();
        this.setCookiePolicy = setCookiePolicy;
    }

    public void setCookie(final Cookie cookie, final HttpRequest request) {
        ArrayList<Cookie> cookies = new ArrayList<Cookie>();
        cookies.add(cookie);
        setCookies(cookies, request);
    }
    
    @Override
    public void setCookies(final Collection<Cookie> cookies, final HttpRequest request) {
        
        URI requestUri = null;
        try {
            requestUri = CookieUtils.makeSafeURI(request.getUri());
        }
        catch (URISyntaxException e) {
            log.debug("rejecting set-cookies {} from unparseable uri {}", 
                      cookies, request.getUri());
            return;
        }

        // create a CookieFilter for this request that represents 
        // the policy for setting cookies in this tracker.
        CookieFilter setCookieFilter = setCookiePolicy.createCookieFilter(request);

        for (Cookie cookie : cookies) {

            // create a normalized clone with some additional storage flags
            final StoredCookie storedCookie = StoredCookie.fromSetCookie(cookie, requestUri);

            if (shouldStoreCookie(storedCookie, setCookieFilter, request)) {
                storeCookie(storedCookie);
                log.debug("Accepted Set-Cookie {} from {} (normalized to {})",
                          new Object[]{cookie, request.getUri(), storedCookie});
            }
            else {
                log.debug("rejected Set-Cookie {} from {} (normalized as {})", 
                          new Object[]{cookie, request.getUri(), storedCookie});
            }
        }
    }
    
    /** 
     * called for each cookie to test whether it should be 
     * stored.  By default this defers to the cookiefilter 
     * given.
     */ 
    protected boolean shouldStoreCookie(StoredCookie cookie, CookieFilter setCookieFilter, HttpRequest request) {
        return setCookieFilter.accepts(cookie);
    }
    
    /**
     * called internally to store a cookie in this tracker.
     * 
     */ 
    protected void storeCookie(StoredCookie cookie) {
        final CookieKey key = new CookieKey(cookie);

        // adopt the creation timestamp of any existing stored cookie with 
        // the identical key (what we are replacing) according to 
        // RFC6265 Section 5.3.11 
        final CookieHolder existing = storedCookies.get(key); 
        if (existing != null) {
            cookie.setCreationTimestamp(existing.getCookie().getCreationTimestamp());
        }
        storedCookies.put(key, new CookieHolder(cookie));
    }

    /**
     * @return true if and only if this tracker observed a valid Set-Cookie 
     * with the same name as the Cookie given that could legitimately 
     * be sent to the requestUri according to normal browser sending policy 
     * (specifically RFC 6265) and is not expired.
     */
    public boolean wouldSendCookie(final Cookie cookie, final URI toRequestUri) {
        return wouldSendCookie(cookie, toRequestUri, false);
    }

    /**
     * @return true if and only if this tracker observed a valid Set-Cookie 
     * with the same name (and optionally value) as the Cookie given that could legitimately 
     * be sent to the requestUri according to normal browser sending policy 
     * (specifically RFC 6265) and is not expired.
     */
    public boolean wouldSendCookie(final Cookie cookie, final URI toRequestUri, final boolean requireValueMatch) {
        // find all the cookies with the same name...
        final String cookieName = cookie.getName(); 
        final String cookieValue = cookie.getValue();

        final CookieKey byName = new CookieKey(cookieName, "", "");
        for (CookieHolder val : storedCookies.tailMap(byName).values()) {
            final StoredCookie storedCookie = val.getCookie(); 

            // stop iteration when we reach a Cookie with a different Name.
            // these are ordered first by name, so this will cover all 
            // cookies with the same name before terminating.
            if (!storedCookie.getName().equals(cookieName)) {
                return false;
            }

            // if we require a value match, and the values don't match, skip it. 
            if (requireValueMatch && !storedCookie.getValue().equals(cookieValue)) {
                continue; 
            }
            
            // if the cookie is expired, skip it, it is not considered a part of
            // the store since it is required to be immediately "evicted" on 
            // expiry according to RFC6265 Section 5.3.12 -- we actually discard 
            // it when discardExpiredCookies() is called.
            if (storedCookie.isExpired()) {
                continue;
            }

            // if we passed all of the above and this cookie is a match
            // domain and path-wise according to RFC6265 Section 5.4.1, 
            // then the answer is Yes, we would send this cookie.
            if (CookieUtils.canBeSent(storedCookie, toRequestUri)) {
                return true;
            }
        }
        return false;
    }

    /**
     * @return a CookieFilter that accepts Cookies whenever wouldSendCookie  
     * is true and false otherwise on this CookieTracker.
     *
     * if requireValueMatch is true, the cookie's value will also be required
     * to match some cookie in the cookie tracker.
     *
     * Value matching prevents upstream proxies from poisoning lantern's
     * cookie jar in a meaningful way -- for example in order to force a
     * cookie to be whitelisted, an upstream proxy could inject a cookie with 
     * the desired name (and an arbirtrary value) into a downstream response 
     * prior to the desired cookie being set over a secure channel.  In this 
     * case, without value matching, lantern would allow the cookie to be sent 
     * upstream.
     * 
     * Value matching can overfilter in cases where the value of the cookie is
     * determined by an unpredicatable race in the client (same cookie being set
     * to multiple values close in time) or the client disagrees with lantern's 
     * cookie storage policy in certain ways.
     *
     */
    public CookieFilter asUpstreamCookieFilter(final HttpRequest request, final boolean requireValueMatch) throws URISyntaxException {
        final URI requestUri = CookieUtils.makeSafeURI(request.getUri());
        return new CookieFilter() {
            @Override
            public boolean accepts(Cookie cookie) {
                return wouldSendCookie(cookie, requestUri, requireValueMatch);
            }
        };
    }

    /** 
     * Discards stored cookies that are expired. 
     *
     */
    public void discardExpiredCookies() {
        final Set<Map.Entry<CookieKey, CookieHolder>> toDelete = new HashSet<Map.Entry<CookieKey, CookieHolder>>(); 

        // iterate all cookies, gather entries that need to be deleted.       
        for (Map.Entry<CookieKey, CookieHolder> me : storedCookies.entrySet()) {
            if (me.getValue().getCookie().isExpired()) {
                toDelete.add(me);
            }
        }
        // delete the cookies gathered in the prior loop
        for (Map.Entry<CookieKey, CookieHolder> me: toDelete) {
            // this should only remove if the cookie stored
            // with the key in the entry equals() the cookie 
            // we saw above. This is a necessary precaution 
            // because a new cookie may have been written into 
            // the store with different information changing
            // the expiration status of the cookie between 
            // detection and deletion.
            storedCookies.remove(me.getKey(), me.getValue());
        }
    }

    /**
     * immutable helper key class for controlling how cookies
     * are sorted in the store.  Currently this is 
     * just (name, domain, path) order.
     */ 
    class CookieKey implements Comparable<CookieKey> {
        private final String name; 
        private final String domain; 
        private final String path;

        public CookieKey(final StoredCookie forCookie) {
            this(forCookie.getName(), forCookie.getDomain(), forCookie.getPath());
        }

        public CookieKey(final String name, final String domain, final String path) {
            if (name == null) {
                this.name = "";
            }
            else {
                this.name = name;
            }
            
            if (domain == null) {
                this.domain = "";
            }
            else {
                this.domain = CookieUtils.canonicalizeHost(domain);
            }
            
            if (path == null) {
                this.path = "";
            }            
            else {
                this.path = path;
            }
            
        }

        @Override
        public int hashCode() {
            return new HashCodeBuilder().
                append(name).
                append(domain).
                append(path).toHashCode();            
        }

        @Override 
        public boolean equals(final Object o) {
            if (!(o instanceof CookieKey)) {
                return false;
            }
            final CookieKey other = (CookieKey) o;
            return ((this.name.equals(other.name)) &&
                    (this.domain.equals(other.domain)) &&
                    (this.path.equals(other.path)));
        }

        @Override
        public int compareTo(final CookieKey c) {
            int v;
            v = name.compareTo(c.name);
            if (v != 0) {
                return v;
            }

            v = domain.compareTo(c.domain);
            if (v != 0) {
                return v;
            }

            v = path.compareTo(c.path);
            return v;
        }
    }
    
    /** 
     * A class that holds a StoredCookie and adapts the 
     * equals and compareTo semantics of a StoredCookie 
     * without violating the constraints imposed by the 
     * Cookie interface / netty implementation. 
     * 
     * It is not possible to change the definition of 
     * equals on StoredCookie to consider new fields
     * without making compareTo inconsistent with equals. 
     * 
     * likewise, compareTo cannot be overridden since the 
     * interface is declared to compare all objects of 
     * class Cookie and compareTo must be antisymmetric.
     * 
     * DefaultCookie imposes very loose definitions of 
     * equals and compareTo (utilizing only name, domain and path)
     * which make sense in some circumstances but are 
     * not sufficient for equivalence comparison in this 
     * cookie store.  For example when making a call to 
     * remove with the requirement that the value has not 
     * changed, we cannot only consider whether the name, domain
     * and path have not changed, but must also consider 
     * maximum age etc.
     * 
     */ 
    class CookieHolder implements Comparable<CookieHolder> {

        private StoredCookie cookie;

        public CookieHolder(StoredCookie c) {
            cookie = c;
        }
        
        public StoredCookie getCookie() {
            return cookie;
        }
        
        @Override
        public boolean equals(final Object other) {
            if (this == other) {
                return true;
            }

            if (!(other instanceof CookieHolder)) {
                return false;
            }

            CookieHolder o = (CookieHolder) other;

            final StoredCookie a = cookie;
            final StoredCookie b = o.cookie;

            if (a == b) {
                return true;
            }

            // these values should include any that 
            // would change functional equivalence.

            // name
            final String nameA = a.getName(); 
            final String nameB = b.getName();
            if (nameA == null ? nameB != null : !nameA.equals(nameB)) {
                return false;
            }

            // domain 
            final String domainA = a.getDomain();
            final String domainB = b.getDomain();
            if (domainA == null ? domainB != null : !domainA.equals(domainB)) {
                return false;
            }

            // path
            final String pathA = a.getPath();
            final String pathB = b.getPath();
            if (pathA == null ? pathB != null : !pathA.equals(pathB)) {
                return false;
            }

            if (a.getMaxAge() != b.getMaxAge() || 
                a.isSecure() != b.isSecure() || 
                a.isPersistent() != b.isPersistent() ||
                a.isHostOnly() != b.isHostOnly() || 
                a.getCreationTimestamp() != b.getCreationTimestamp()) {
                return false;
            }

            return true;
        }

        public int compareTo(final CookieHolder o) {

            if (this == o) {
                return 0;
            }

            final StoredCookie a = cookie;
            final StoredCookie b = o.cookie;

            if (a == b) {
                return 0;
            }

            int v;

            // Natural sort order first follows recommendation of RFC6265 
            // Section 5.4.2 (for outbound Cookies)
            //
            // 2.  The user agent SHOULD sort the cookie-list in the following
            //     order:
            // 
            //        *  Cookies with longer paths are listed before cookies with
            //           shorter paths.
            // 
            //        *  Among cookies that have equal-length path fields, cookies with
            //           earlier creation-times are listed before cookies with later
            //           creation-times.
            //
            // Sorted like tuples of the form:
            // (-getPath().length(), getCreationTimestamp(), ...other fields)

            // path length
            int p1 = 0; 
            int p2 = 0; 
            if (a.getPath() != null) {
                p1 = -a.getPath().length();
            }
            if (b.getPath() != null) {
                p2 = -b.getPath().length(); 
            }
            v = p1 - p2;
            if (v != 0) {
                return v;
            }

            // creation date
            long vl = a.getCreationTimestamp() - b.getCreationTimestamp(); 
            if (vl != 0) {
                if (vl > 0) {
                    return 1; 
                }
                else {
                    return -1;
                }
            }

            v = _stringCmp(a.getName(), b.getName());
            if (v != 0) {
                return v;
            }
            v = _stringCmp(a.getDomain(), b.getDomain());
            if (v != 0) {
                return v;
            }
            v = _stringCmp(a.getPath(), b.getPath()); 
            if (v != 0) {
                return v;
            }

            v = a.getMaxAge() - b.getMaxAge();
            if (v != 0) {
                return v;
            }

            if (a.isSecure() != b.isSecure()) {
                return a.isSecure() ? 1 : -1;
            }
            if (a.isPersistent() != b.isPersistent()) {
                return a.isPersistent() ? 1 : -1;
            }
            if (a.isHostOnly() != b.isHostOnly()) {
                return a.isHostOnly() ? 1 : -1;
            }

            return 0;
        }

        private int _stringCmp(final String a, final String b) {
            if (a == null) {
                if (b == null) {
                    return 0;
                }
                return -1;
            }
            if (b == null) {
                return 1;
            }
            return a.compareTo(b);
        }
    }

}