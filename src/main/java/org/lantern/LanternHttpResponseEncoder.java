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
    private final ClientStats stats;


    public LanternHttpResponseEncoder(final ClientStats stats) {
        super(true);
        this.stats = stats; 
    }

    @Override
    protected Object encode(final ChannelHandlerContext ctx, 
        final Channel channel, final Object msg) throws Exception {
        final ChannelBuffer cb = 
            (ChannelBuffer) super.encode(ctx, channel, msg);
        if (cb == null) {
            return null;
        }
        final int bytes = cb.readableBytes();
        if (msg instanceof ProxyHttpResponse) {
            // This is called when we just pass unproxied requests over to
            // LittleProxy.
            this.stats.addDirectBytes(bytes);
        } else {
            // If it's *not* a ProxyHttpResponse, that means it's something
            // we didn't simply pass to LittleProxy and instead proxied
            // ourselves. This could be a straight ChannelBuffer from a p2p
            // socket, relayed non-HTTP CONNECT data from one of our proxies.
            // HTTP CONNECT data has to be accounted for differently, as it
            // bypassed any encoder.
            
            // global bytes proxied statistic
            this.stats.addBytesProxied(bytes, channel);
        }
        return cb;
    }
}
