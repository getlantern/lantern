package org.lantern;

import java.net.InetSocketAddress;

import org.apache.commons.lang.StringUtils;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Modified HTTP requests to work with Google App Engine as a proxy.
 */
public class LaeHttpRequestTransformer implements HttpRequestTransformer {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Override
    public void transform(final HttpRequest request,
        final InetSocketAddress proxyAddress) {
        final String uri = request.getUri();
        
        final String host = proxyAddress.getHostName();
        final String proxyBaseUri = "https://" + host;
        if (!uri.startsWith(proxyBaseUri)) {
            request.setHeader("Host", host);
            final String scheme = uri.substring(0, uri.indexOf(':'));
            final String rest = uri.substring(scheme.length() + 3);
            final String proxyUri = proxyBaseUri + "/" + scheme + "/" + rest;
            log.debug("proxyUri: " + proxyUri);
            request.setUri(proxyUri);
        } else {
            log.info("NOT MODIFYING URI -- ALREADY HAS HOST");
        }
        
        final String range = request.getHeader(HttpHeaders.Names.RANGE);
        if (StringUtils.isNotBlank(range)) {
            log.info("Request already has range!");
            return;
        }
        
        request.setHeader(HttpHeaders.Names.RANGE, 
            "bytes=0-"+LanternConstants.CHUNK_SIZE);
    }

}
