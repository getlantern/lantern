package org.lantern.httpseverywhere;


/* Class representing a parsed HTTPS Everywhere securecookie rule */
public class HttpsSecureCookieRule {

    private final String host;
    private final String name;

    public HttpsSecureCookieRule(final String host, final String name) {
        this.host = host;
        this.name = name;
    }

    public boolean nameMatches(final String cookieName) {
        // XXX these are javascript regular expressions. 
        // mostly should work, but no actual guarantee until run
        return cookieName.matches(name);
    }
    
    public String getHost() {
        return host;
    }
    
    public String getName() {
        return name;
    }

    @Override
    public String toString() {
        return "HttpsSecureCookieRule [host=" + host + ", name=" + name + "]";
    }


}