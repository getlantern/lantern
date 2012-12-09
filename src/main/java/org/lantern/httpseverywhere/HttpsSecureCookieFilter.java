package org.lantern.httpseverywhere; 

import java.util.ArrayList;
import java.util.Collection;

import org.jboss.netty.handler.codec.http.Cookie;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.lantern.cookie.CookieFilter;
import org.lantern.httpseverywhere.HttpsEverywhere.HttpsRuleSet;

/**
 * filters any outbound Cookie header that 
 * matches an HttpsEverywhere securecookie rule 
 * applicable to the requested url.
 *
 * Note this does not implement the intended behavior
 * of an HTTPSEverywhere securecookie rule! The intention
 * of securecookie rules is to set the "Secure" flag on 
 * securely transferred Set-Cookie headers.  Lantern 
 * cannot observe or modify these, but it can filter
 * upstream Cookie headers. 
 * 
 * This may severely overfilter cookies if used as-is
 * depending on the behavior of the site. In many cases 
 * HTTPSEverywhere securecookie rules select *all* 
 * cookies -- (which is intended to mean all securely 
 * set cookies) To implement something closer to this
 * policy, see HttpBestEffortCookieFilter.
 * 
 */ 
public class HttpsSecureCookieFilter implements CookieFilter {
    
    private final Collection<HttpsSecureCookieRule> rules = 
        new ArrayList<HttpsSecureCookieRule>();
    
    public HttpsSecureCookieFilter(final HttpRequest context, 
        final HttpsEverywhere httpsEverywhere) {
        for (HttpsRuleSet ruleSet : httpsEverywhere.getApplicableRuleSets(context.getUri())) {
            for (HttpsSecureCookieRule rule : ruleSet.getSecureCookieRules()) {
                rules.add(rule);
            }
        }
    }

    public HttpsSecureCookieFilter(final Collection<HttpsSecureCookieRule> rules) {
        for (HttpsSecureCookieRule rule : rules) {
            this.rules.add(rule);
        }
    }
    
    @Override
    public boolean accepts(final Cookie cookie) {
        final String cookieName = cookie.getName();
        for (HttpsSecureCookieRule rule : rules) {
            if (rule.nameMatches(cookieName)) {
                return false;
            }
        }
        return true; // no match.
    }
}