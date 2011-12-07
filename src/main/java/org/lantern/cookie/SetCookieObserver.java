package org.lantern.cookie;

import java.util.Collection;
import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.HttpRequest; 

/**
 * Interface for receiving notification of downstream 
 * Set-Cookie headers.
 */
public interface SetCookieObserver {

    /**
     * Called when Set-Cookie headers are received.
     * 
     * Note: these are raw results which may contain illegal Set-Cookie
     *       header values.
     * 
     * @param cookies    the parsed Set-Cookie header values
     * @param request    the HttpRequest in response to which
     *                   the Set-Cookie header was sent. 
     */
    public void setCookies(Collection<Cookie> cookies, HttpRequest context);

}