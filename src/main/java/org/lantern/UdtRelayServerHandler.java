package org.lantern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import io.netty.buffer.ByteBuf;
import io.netty.channel.ChannelHandler.Sharable;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundByteHandlerAdapter;
import io.netty.channel.ChannelOption;
import io.netty.channel.udt.nio.NioUdtProvider;

/**
 * Handler implementation for the echo server.
 */
@Sharable
public class UdtRelayServerHandler extends ChannelInboundByteHandlerAdapter {

    private static final Logger log = 
        LoggerFactory.getLogger(UdtRelayServerHandler.class.getName());
    private final int relayPort;

    public UdtRelayServerHandler(final int relayPort) {
        this.relayPort = relayPort;
    }

    @Override
    public void inboundBufferUpdated(final ChannelHandlerContext ctx,
        final ByteBuf in) {
        log.debug("Got inboundBufferUpdated!!!!!!!");
        final ByteBuf out = ctx.nextOutboundByteBuffer();
        out.discardReadBytes();
        out.writeBytes(in);
        ctx.flush();
    }

    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx,
            final Throwable cause) {
        log.debug("Close the connection when an exception is raised", cause);
        ctx.close();
    }

    @Override
    public void channelActive(final ChannelHandlerContext ctx) throws Exception {
        log.info("ECHO active " + NioUdtProvider.socketUDT(ctx.channel()).toStringOptions());
    }

    @Override
    public ByteBuf newInboundBuffer(final ChannelHandlerContext ctx)
            throws Exception {
        return ctx.alloc().directBuffer(
                ctx.channel().config().getOption(ChannelOption.SO_RCVBUF));
    }
}
