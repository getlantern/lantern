package org.lantern.proxy;

import io.netty.handler.codec.http.DefaultHttpRequest;
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

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class GetModeProxyFilter extends HttpFiltersSourceAdapter {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    private final AtomicBoolean highQos = new AtomicBoolean(false);
    
    @Inject
    public GetModeProxyFilter() {
    }
    
    @Override
    public HttpFilters filterRequest(HttpRequest originalRequest) {
        return new HttpFiltersAdapter(originalRequest, null) {
            @Override
            public HttpResponse requestPre(HttpObject httpObject) {
                log.info("Intercepted request: {}", httpObject);
                if (highQos.get() && httpObject instanceof DefaultHttpRequest) {
                    log.info("Adding QOS header");
                    ((DefaultHttpRequest)httpObject).headers().add(
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
