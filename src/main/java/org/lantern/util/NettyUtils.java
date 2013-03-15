package org.lantern.util;

import io.netty.buffer.ByteBuf;

import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;

public class NettyUtils {
    
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
}
