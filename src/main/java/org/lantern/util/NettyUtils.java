package org.lantern.util;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.Unpooled;

import java.util.Queue;

import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.lantern.udtrelay.ChannelAdapter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class NettyUtils {
    
    private static final Logger LOG = LoggerFactory.getLogger(NettyUtils.class);
    
    public static void copyByteBufToChannel(final ByteBuf in, final Channel out) {
        final byte[] data = new byte[in.readableBytes()];
        in.readBytes(data);
        out.write(ChannelBuffers.wrappedBuffer(data));
    }


    /**
     * Closes the specified channel after all queued write requests are flushed.
     */
    public static void closeOnFlush(final io.netty.channel.Channel ch) {
        if (ch.isActive()) {
            ch.flush().addListener(io.netty.channel.ChannelFutureListener.CLOSE);
        }
    }
    

    /**
     * Helper method that ensures all written requests are properly recorded.
     *
     * @param request The request.
     */
    public static void writeRequest(final Queue<HttpRequest> httpRequests,
        final HttpRequest request, final org.jboss.netty.channel.ChannelFuture cf) {
        httpRequests.add(request);
        LOG.debug("Writing request: {}", request);
        genericWrite(request, cf);
    }

    public static void genericWrite(final Object message,
        final ChannelFuture future) {
        final Channel ch = future.getChannel();
        if (ch.isConnected()) {
            ch.write(message);
        } else {
            future.addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(final ChannelFuture cf)
                    throws Exception {
                    if (cf.isSuccess()) {
                        ch.write(message);
                    }
                }
            });
        }
    }


    public static ByteBuf channelBufferToByteBuf(final ChannelBuffer cb) {
        return Unpooled.wrappedBuffer(cb.toByteBuffer());
    }

    public static final class HttpRequestConverter extends HttpRequestEncoder {
        private org.jboss.netty.channel.Channel basicChannel = new ChannelAdapter();

        public ByteBuf encode(final Object msg) throws Exception {
            final org.jboss.netty.buffer.ChannelBuffer cb = 
                (org.jboss.netty.buffer.ChannelBuffer) super.encode(null, basicChannel, msg);
            return Unpooled.wrappedBuffer(cb.toByteBuffer());
        }
    };
    
    public static final HttpRequestConverter encoder = new HttpRequestConverter();
    
    public static void writeRequest(final HttpRequest request, 
            final io.netty.channel.ChannelFuture cf) 
        throws Exception {
        LOG.debug("Writing request: {}", request);
        genericWrite(encoder.encode(request), cf);
    }
    
    public static void genericWrite(final ByteBuf message,
        final io.netty.channel.ChannelFuture future) {
        final io.netty.channel.Channel ch = future.channel();
        if (ch.isOpen()) {
            ch.write(message);
        } else {
            future.addListener(new io.netty.channel.ChannelFutureListener() {
                
                @Override
                public void operationComplete(
                    final io.netty.channel.ChannelFuture cf) throws Exception {
                    if (cf.isSuccess()) {
                        ch.write(message);
                    }
                }
            });
        }
    }
}
