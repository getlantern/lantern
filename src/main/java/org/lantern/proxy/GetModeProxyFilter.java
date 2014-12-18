package org.lantern.proxy;

import io.netty.handler.codec.http.HttpObject;
import io.netty.handler.codec.http.HttpRequest;
import io.netty.handler.codec.http.HttpResponse;

import java.util.concurrent.atomic.AtomicBoolean;

import org.lantern.proxy.pt.Flashlight;
import org.littleshoot.proxy.HttpFilters;
import org.littleshoot.proxy.HttpFiltersAdapter;
import org.littleshoot.proxy.HttpFiltersSourceAdapter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Singleton;

/**
 * This class filters incoming requests and adds the high QoS HTTP header if 
 * it's configured to do so. This is useful, for example, for adding the high
 * QoS header to the Google OAuth requests from the Lantern UI that go through
 * Lantern by way of the system proxy configuration.
 */
@Singleton
public class GetModeProxyFilter extends HttpFiltersSourceAdapter {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    private final AtomicBoolean highQos = new AtomicBoolean(false);
    
    @Override
    public HttpFilters filterRequest(HttpRequest originalRequest) {
        return new HttpFiltersAdapter(originalRequest, null) {
            @Override
            public HttpResponse requestPre(HttpObject httpObject) {
                if (highQos.get() && httpObject instanceof HttpRequest) {
                    log.info("Adding QOS header");
                    ((HttpRequest)httpObject).headers().add(
                            Flashlight.X_FLASHLIGHT_QOS, Flashlight.HIGH_QOS);
                }
                return null;
            }
        };
    }
    
    public void setHighQos(final boolean proxyAll) {
        this.highQos.set(proxyAll);
    }
}
