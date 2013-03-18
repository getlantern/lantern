package org.lantern.udtrelay;

import io.netty.buffer.ByteBuf;
import io.netty.channel.Channel;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundByteHandlerAdapter;

import org.lantern.util.NettyUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * UDT relay backend handler that processes incoming data and sends it to the
 * destination server.
 */
public class UdtRelayServerBackendHandler extends ChannelInboundByteHandlerAdapter {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Channel inboundChannel;

    public UdtRelayServerBackendHandler(Channel inboundChannel) {
        this.inboundChannel = inboundChannel;
    }

    @Override
    public void channelActive(final ChannelHandlerContext ctx) throws Exception {
        log.debug("Backend channel active: {}", ctx.channel());
        ctx.read();
        ctx.flush();
    }

    @Override
    public void inboundBufferUpdated(final ChannelHandlerContext ctx, 
        final ByteBuf in) throws Exception {
        log.debug("Got inbound buffer on BACKEND updated from...");
        final ByteBuf out = inboundChannel.outboundByteBuffer();
        out.writeBytes(in);
        inboundChannel.flush().addListener(new ChannelFutureListener() {
            @Override
            public void operationComplete(final ChannelFuture future) 
                throws Exception {
                if (future.isSuccess()) {
                    ctx.channel().read();
                } else {
                    log.debug("Closing channel");
                    future.channel().close();
                }
            }
        });
    }

    @Override
    public void channelInactive(final ChannelHandlerContext ctx) 
        throws Exception {
        log.debug("Closing inactive inbound channel: {}", inboundChannel);
        NettyUtils.closeOnFlush(inboundChannel);
    }

    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final Throwable cause) throws Exception {
        cause.printStackTrace();
        log.debug("Closing channel with error", cause);
        NettyUtils.closeOnFlush(ctx.channel());
    }
}
