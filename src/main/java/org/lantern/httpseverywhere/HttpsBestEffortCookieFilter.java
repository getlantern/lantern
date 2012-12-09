package org.lantern.httpseverywhere; 


import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.lantern.cookie.CookieFilter;

/**
 *
 * Implements a best effort strategy for filtering 
 * cookies in a manner that is similar to HttpsEverywhere 
 * secure cookie rules. 
 * 
 * Secure cookie rules cannot be directly implemented in the intended way 
 * because they describe setting a flag ("Secure") on Set-Cookies, 
 * ostensibly sent over a secure channel that lantern cannot observe or modify. 
 *
 * Instead, this policy eliminates any Cookie headers (not Set-Cookie)
 * sent by the *browser* that match secure cookie rules unless they 
 * are on a whitelist.  
 *
 * The whitelist is arbitrary, but is intented to represent any cookie 
 * that was previously observed being set over an insecure channel 
 * (hence already comprimised or unimportant) For example, 
 * @see lantern.cookie.InMemoryCookieTracker.asOutboundCookieFilter
 *
 */ 
public class HttpsBestEffortCookieFilter implements CookieFilter {
    
    private final CookieFilter whitelist;
    private final CookieFilter blacklist;
    
    /**
     * constructs a new HttpBestEffortCookieFilter with
     * a given "seen" cookie whitelist. 
     * 
     * @param whitelist Any Cookie accepted by this filter will also 
     * be accepted by this filter. For example, 
     * @see lantern.cookie.InMemoryCookieTracker.asOutboundCookieFilter.
     *
     */
    public HttpsBestEffortCookieFilter(final CookieFilter whitelist, 
        final HttpRequest context, final HttpsEverywhere httpsEverywhere) {
        this(whitelist, new HttpsSecureCookieFilter(context, httpsEverywhere));
    }
    
    public HttpsBestEffortCookieFilter(final CookieFilter whitelist, 
        final CookieFilter blacklist) {
        this.whitelist = whitelist; 
        this.blacklist = blacklist;
    }
    
    @Override
    public boolean accepts(final Cookie cookie) {
        if (whitelist.accepts(cookie)) {
            return true;
        }
        return blacklist.accepts(cookie); 
    }
}