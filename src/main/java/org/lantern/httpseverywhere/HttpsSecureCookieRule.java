package org.lantern.httpseverywhere;

import java.util.regex.Pattern;

/* Class representing a parsed HTTPS Everywhere securecookie rule */
public class HttpsSecureCookieRule {

    public final String host;
    public final String name;

    public HttpsSecureCookieRule(final String host, final String name) {
        this.host = host;
        this.name = name;
    }

    public boolean nameMatches(final String cookieName) {
        // XXX these are javascript regular expressions. 
        // mostly should work, but no actual guarantee until run
        return cookieName.matches(name);
    }

    @Override
    public String toString() {
        return "HttpsSecureCookieRule [host=" + host + ", name=" + name + "]";
    }
}