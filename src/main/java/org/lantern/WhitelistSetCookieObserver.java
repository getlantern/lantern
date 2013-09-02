package org.lantern;

import io.netty.handler.codec.http.Cookie;
import io.netty.handler.codec.http.HttpRequest;

import java.util.Collection;

import org.lantern.cookie.SetCookieObserver;

/**
 * simple wrapper SetCookieObserver that skips Cookies
 * that are not from requests on the whitelist. 
 * Delegates all other cookie policy to another observer.
 */ 
class WhitelistSetCookieObserver implements SetCookieObserver {
    private final SetCookieObserver observer;

    WhitelistSetCookieObserver(SetCookieObserver observer) {
        this.observer = observer;
    }

    @Override
    public void setCookies(final Collection<Cookie> cookies, final HttpRequest context) {
        observer.setCookies(cookies, context);
    }
}