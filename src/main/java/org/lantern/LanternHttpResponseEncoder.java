package org.lantern;

import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.littleshoot.proxy.ProxyHttpResponse;
import org.littleshoot.proxy.ProxyHttpResponseEncoder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * HTTP response encoder for Lantern that sends responses back to the browser
 * and keeps statistics on bytes proxied.
 */
public class LanternHttpResponseEncoder extends ProxyHttpResponseEncoder {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final StatsTracker statsTracker;

    public LanternHttpResponseEncoder(final StatsTracker statsTracker) {
        super(true); 
        this.statsTracker = statsTracker;
    }

    @Override
    protected Object encode(final ChannelHandlerContext ctx, 
        final Channel channel, final Object msg) throws Exception {
        final ChannelBuffer cb = 
            (ChannelBuffer) super.encode(ctx, channel, msg);
        final int bytes = cb.readableBytes();
        log.info("Bytes: " + bytes);
        if (msg instanceof ProxyHttpResponse) {
            this.statsTracker.addDirectBytes(bytes);
            this.statsTracker.incrementDirectRequests();
        } else {
            // If it's *not* a ProxyHttpResponse, that means it's something
            // we didn't simply pass to LittleProxy and instead proxied
            // ourselves.
            this.statsTracker.addBytesProxied(bytes);
            this.statsTracker.incrementProxiedRequests();
        }
        return cb;
    }
}
