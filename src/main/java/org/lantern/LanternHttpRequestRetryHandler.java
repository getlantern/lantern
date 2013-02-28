package org.lantern;

import java.io.IOException;
import java.io.InterruptedIOException;
import java.net.ConnectException;
import java.net.UnknownHostException;

import javax.net.ssl.SSLException;

import org.apache.http.HttpHost;
import org.apache.http.client.HttpClient;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.impl.client.DefaultHttpRequestRetryHandler;
import org.apache.http.protocol.HttpContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * An HTTP client retry handler that first tries requests directly and then
 * tries them via a proxy if they repeatedly don't work directly.
 */
public class LanternHttpRequestRetryHandler 
    extends DefaultHttpRequestRetryHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final HttpClient httpClient;

    public LanternHttpRequestRetryHandler(final HttpClient httpClient) {
        super(2, false);
        this.httpClient = httpClient;
    }
    
    @Override
    public boolean retryRequest(final IOException exception,
        final int executionCount, final HttpContext context) {
        log.debug("Checking for retry...");
        final boolean standard = 
            super.retryRequest(exception, executionCount, context);
        if (!standard) {
            log.debug("Checking execution count...");
            if (executionCount < (getRetryCount() * 2)) {
                if (isBlockingException(exception)) {
                    log.debug("Got a blocking exception...applying proxy");
                    final HttpHost proxy = 
                        new HttpHost(LanternClientConstants.FALLBACK_SERVER_HOST, 
                            Integer.valueOf(LanternClientConstants.FALLBACK_SERVER_PORT), 
                            "https");
                    this.httpClient.getParams().setParameter(
                        ConnRoutePNames.DEFAULT_PROXY, proxy);
                    return true;
                }
            }
        }
        return standard;
    }

    private boolean isBlockingException(final IOException exception) {
        log.debug("Checking if we should proxy...", exception);
        if (exception instanceof ConnectException) {
            // Connection refused
            return true;
        } 
        if (exception instanceof UnknownHostException) {
            // Unknown host
            return true;
        }
        if (exception instanceof SSLException) {
            // SSL handshake exception
            return true;
        }
        if (exception instanceof InterruptedIOException) {
            // Timeout
            return true;
        }
        return false;
    }
}
