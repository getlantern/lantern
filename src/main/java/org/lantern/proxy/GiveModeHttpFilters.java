package org.lantern.proxy;

import io.netty.handler.codec.http.DefaultFullHttpResponse;
import io.netty.handler.codec.http.HttpObject;
import io.netty.handler.codec.http.HttpRequest;
import io.netty.handler.codec.http.HttpResponse;
import io.netty.handler.codec.http.HttpResponseStatus;

import java.net.InetAddress;
import java.net.UnknownHostException;

import org.apache.commons.lang3.StringUtils;
import org.littleshoot.proxy.HttpFiltersAdapter;
import org.littleshoot.proxy.impl.ProxyUtils;
import org.littleshoot.util.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Filters used when proxying in Give mode.
 */
public class GiveModeHttpFilters extends HttpFiltersAdapter {

    private static final Logger LOG = LoggerFactory
            .getLogger(GiveModeHttpFilters.class);

    public GiveModeHttpFilters(HttpRequest originalRequest) {
        super(originalRequest);
    }

    /**
     * When running in Give mode, we only allow requests to public addresses.
     */
    @Override
    public HttpResponse requestPre(HttpObject httpObject) {
        String hostAndPort = ProxyUtils.parseHostAndPort(originalRequest
                .getUri());
        final String host;
        if (hostAndPort.contains(":")) {
            host = StringUtils.substringBefore(hostAndPort, ":");
        } else {
            host = hostAndPort;
        }
        try {
            final InetAddress ia = InetAddress.getByName(host);
            if (NetworkUtils.isPublicAddress(ia)) {
                LOG.debug("Allowing request for public address");
            } else {
                // We do this for security reasons -- we don't
                // want to allow proxies to inadvertantly expose
                // internal network services.
                LOG.warn(
                        "Request for non-public resource: {} on address: {}\n full request: {}",
                        originalRequest.getUri(), ia, originalRequest);
                return forbidden();
            }
        } catch (final UnknownHostException uhe) {
            return forbidden();
        }
        return null;
    }

    private HttpResponse forbidden() {
        return new DefaultFullHttpResponse(
                originalRequest.getProtocolVersion(),
                HttpResponseStatus.FORBIDDEN);
    }

}