package org.lantern;

//import com.yammer.metrics.Metrics;
//import com.yammer.metrics.core.Meter;
import io.netty.buffer.ByteBuf;
import io.netty.buffer.Unpooled;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundByteHandlerAdapter;
import io.netty.channel.ChannelOption;
import io.netty.channel.udt.nio.NioUdtProvider;

import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Handler implementation for the echo client. It initiates the ping-pong
 * traffic between the echo client and server by sending the first message to
 * the server on activation.
 */
public class UdtClientRelayHandler extends ChannelInboundByteHandlerAdapter {

    private static final Logger log = Logger.getLogger(UdtClientRelayHandler.class.getName());

    private final ByteBuf message;

    //final Meter meter = Metrics.newMeter(ByteEchoClientHandler.class, "rate",
    //        "bytes", TimeUnit.SECONDS);

    public UdtClientRelayHandler(final int messageSize) {
        message = Unpooled.buffer(messageSize);

        for (int i = 0; i < message.capacity(); i++) {
            message.writeByte((byte) i);
        }
    }

    @Override
    public void channelActive(final ChannelHandlerContext ctx) throws Exception {
        log.info("ECHO active " + NioUdtProvider.socketUDT(ctx.channel()).toStringOptions());
        ctx.write(message);
    }

    @Override
    public void inboundBufferUpdated(final ChannelHandlerContext ctx,
            final ByteBuf in) {
        //meter.mark(in.readableBytes());
        log.info("Got inbound buffer upated");
        final ByteBuf out = ctx.nextOutboundByteBuffer();
        out.discardReadBytes();
        out.writeBytes(in);
        ctx.flush();
    }

    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx,
            final Throwable cause) {
        log.log(Level.WARNING, "close the connection when an exception is raised", cause);
        ctx.close();
    }

    @Override
    public ByteBuf newInboundBuffer(final ChannelHandlerContext ctx)
            throws Exception {
        return ctx.alloc().directBuffer(
                ctx.channel().config().getOption(ChannelOption.SO_RCVBUF));
    }

}