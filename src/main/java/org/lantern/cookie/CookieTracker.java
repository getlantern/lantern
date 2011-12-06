package org.lantern.cookie;

import java.net.URI;
import java.net.URISyntaxException; 

import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.HttpRequest;

public interface CookieTracker extends SetCookieObserver {
    
    /**
     * @return true if and only if this tracker observed a valid Set-Cookie 
     * with the same name as the Cookie given that could legitimately 
     * be sent to the requestUri according to this policy. 
     */
    public boolean wouldSendCookie(final Cookie cookie, final URI toRequestUri);

    /**
     * @return true if and only if this tracker observed a valid Set-Cookie 
     * with the same name (and optionally value) as the Cookie given that could legitimately 
     * be sent to the requestUri according to this policy.
     */
    public boolean wouldSendCookie(final Cookie cookie, final URI toRequestUri, final boolean requireValueMatch);
    
    /**
     * @return a CookieFilter that accepts Cookies whenever wouldSendCookie  
     * is true and false otherwise on this CookieTracker.
     *
     * if requireValueMatch is true, the cookie's value will also be required
     * to match some cookie observed by the cookie tracker.
     */
    public CookieFilter asOutboundCookieFilter(final HttpRequest request, final boolean requireValueMatch) throws URISyntaxException;
    
}