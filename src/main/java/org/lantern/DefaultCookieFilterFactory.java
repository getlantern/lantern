package org.lantern; 

import org.jboss.netty.handler.codec.http.HttpRequest;
import org.lantern.cookie.CookieFilter;
import org.lantern.cookie.CookieTracker;
import org.lantern.httpseverywhere.HttpsBestEffortCookieFilter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** 
 * represents the default lantern CookieFilter policy
 */ 
class DefaultCookieFilterFactory implements CookieFilter.Factory {
    
    private final CookieTracker tracker;
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    public DefaultCookieFilterFactory(CookieTracker tracker) {
        this.tracker = tracker;
    }

    @Override
    public CookieFilter createCookieFilter(HttpRequest context) {
        if (shouldFilter(context)) {
            try {
                // this uses the cookie tracker's whitelist and does require a value match.
                return new HttpsBestEffortCookieFilter(tracker.asOutboundCookieFilter(context, true), context);

            }
            catch (Exception e) {
                log.error("Unable to create cookie filter for request {}: {}", context, e);
            }
        }
        return null;
    }
    
    /**
     * returns true iff the request should have a cookie filter 
     * applied to it.
     */
    boolean shouldFilter(HttpRequest request) {
        return LanternUtils.shouldProxy(request);
   }
}