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

public class ProxyHttpRequestProcessor implements HttpRequestProcessor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final ProxyProvider proxyProvider;
    private InetSocketAddress proxyAddress;

    /**
     * These need to be synchronized with HTTP responses in the case where we
     * need to issue multiple HTTP range requests in response to 206 responses.
     * This is particularly relevant for LAE because of response size limits.
     */
    private final Queue<HttpRequest> httpRequests = 
        new ConcurrentLinkedQueue<HttpRequest>();
    
    private ChannelFuture cf;

    private final ProxyStatusListener proxyStatusListener;
    
    public ProxyHttpRequestProcessor(final ProxyProvider proxyProvider,
        final ProxyStatusListener proxyStatusListener) {
        this.proxyProvider = proxyProvider;
        this.proxyStatusListener = proxyStatusListener;
    }

    public boolean hasProxy() {
        if (this.proxyAddress != null) {
            return true;
        }
        this.proxyAddress = this.proxyProvider.getProxy();
        if (this.proxyAddress != null) {
            return true;
        }
        return false;
    }

    public void processRequest(final Channel browserToProxyChannel,
        final ChannelHandlerContext ctx, final MessageEvent me) {
        log.info("Centralized proxy processing request");
        // If we can't get a peer socket, we want to use a fallback
        // centralized proxy.
        if (cf == null) {
            cf = LanternUtils.openOutgoingChannel(
                browserToProxyChannel, this.proxyAddress, false, 
                this.httpRequests, this.proxyStatusListener);
        }
        final HttpRequest request = (HttpRequest) me.getMessage();
        LanternUtils.writeRequest(this.httpRequests, request, cf);
    }

    public void processChunk(final ChannelHandlerContext ctx, 
        final MessageEvent me)
        throws IOException {

    }

    public void close() {
        if (cf == null) {
            return;
        }
        LanternUtils.closeOnFlush(this.cf.getChannel());
    }
}
