package org.lantern.cookie; 

import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.HttpRequest;

/**
 * Interface for describing predicates that accept or 
 * reject Cookies. 
 * 
 */
public interface CookieFilter {

    /** 
     * @return true if the given Cookie should be accepted, false otherwise. 
     */
    public boolean accepts(Cookie cookie);

    public interface Factory {
        public CookieFilter createCookieFilter(HttpRequest context);
    }
}