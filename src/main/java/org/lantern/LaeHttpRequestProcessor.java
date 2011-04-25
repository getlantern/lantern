package org.lantern;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LaeHttpRequestProcessor implements HttpRequestProcessor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private ChannelFuture cf;

    /**
     * These need to be synchronized with HTTP responses in the case where we
     * need to issue multiple HTTP range requests in response to 206 responses.
     * This is particularly relevant for LAE because of response size limits.
     */
    private final Queue<HttpRequest> httpRequests = 
        new ConcurrentLinkedQueue<HttpRequest>();

    private final ProxyStatusListener proxyStatusListener;

    private final ProxyProvider proxyProvider;

    private InetSocketAddress proxyAddress;
    
    public LaeHttpRequestProcessor(final ProxyProvider proxyProvider, 
        final ProxyStatusListener proxyStatusListener) {
        this.proxyProvider = proxyProvider;
        this.proxyStatusListener = proxyStatusListener;
    }
    
    public boolean hasProxy() {
        if (this.proxyAddress != null) {
            return true;
        }
        this.proxyAddress = this.proxyProvider.getLaeProxy();
        if (this.proxyAddress != null) {
            return true;
        }
        return false;
    }

    public void processRequest(final Channel browserToProxyChannel,
        final ChannelHandlerContext ctx, final MessageEvent me) {
        
        if (cf == null) {
            cf = LanternUtils.openOutgoingChannel(
                browserToProxyChannel, proxyAddress, true,
                this.httpRequests,
                this.proxyStatusListener);
        }
        final HttpRequest request = (HttpRequest) me.getMessage();
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
            log.info("NOT MODIFYING URI -- ALREADY HAS FREELANTERN");
        }
        LanternUtils.writeRequest(this.httpRequests, request, cf);
    }

    public void processChunk(final ChannelHandlerContext ctx, 
        final MessageEvent me) throws IOException {
        cf.getChannel().write(me.getMessage());
    }

    public void close() {
        if (cf == null) {
            return;
        }
        LanternUtils.closeOnFlush(this.cf.getChannel());
    }
}
