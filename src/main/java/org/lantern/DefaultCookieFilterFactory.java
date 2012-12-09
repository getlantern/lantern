package org.lantern; 

import org.jboss.netty.handler.codec.http.HttpRequest;
import org.lantern.cookie.CookieFilter;
import org.lantern.cookie.CookieTracker;
import org.lantern.httpseverywhere.HttpsBestEffortCookieFilter;
import org.lantern.httpseverywhere.HttpsEverywhere;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** 
 * represents the default lantern CookieFilter policy
 */ 
class DefaultCookieFilterFactory implements CookieFilter.Factory {
    
    private final CookieTracker tracker;
    private final Logger log = LoggerFactory.getLogger(getClass());
    private final HttpsEverywhere httpsEverywhere;
    
    public DefaultCookieFilterFactory(final CookieTracker tracker,
            final HttpsEverywhere httpsEverywhere) {
        this.tracker = tracker;
        this.httpsEverywhere = httpsEverywhere;
    }

    @Override
    public CookieFilter createCookieFilter(HttpRequest context) {
        try {
            // this uses the cookie tracker's whitelist and does require a value match.
            return new HttpsBestEffortCookieFilter(
                tracker.asOutboundCookieFilter(context, true), context, httpsEverywhere);

        }
        catch (Exception e) {
            log.error("Unable to create cookie filter for request {}: {}", context, e);
        }
        return null;
    }
}