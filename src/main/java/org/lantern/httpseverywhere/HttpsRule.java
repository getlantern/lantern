package org.lantern.httpseverywhere;

import org.jboss.netty.handler.codec.http.HttpRequest;

public class HttpsRule {

    private final String from;
    private final String to;

    public HttpsRule(final String from, final String to) {
        this.from = from;
        this.to = to;
    }
    
    public String getFrom() {
        return from;
    }

    public String getTo() {
        return to;
    }
    
    public String apply(final HttpRequest request) {
        return apply(request.getUri());
    }

    public String apply(final String uri) {
        return uri.replaceAll(this.from, this.to);
    }

    @Override
    public String toString() {
        return "HttpsRule [from=" + from + ", to=" + to + "]";
    }
}
