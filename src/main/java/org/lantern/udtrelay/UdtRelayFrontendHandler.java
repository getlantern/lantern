package org.lantern.udtrelay;

import io.netty.bootstrap.Bootstrap;
import io.netty.buffer.ByteBuf;
import io.netty.channel.Channel;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundByteHandlerAdapter;
import io.netty.channel.ChannelOption;
import io.netty.channel.socket.nio.NioSocketChannel;

import org.lantern.LanternClientConstants;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handler for incoming connections to the temporary UDT relay server.
 */
public class UdtRelayFrontendHandler extends ChannelInboundByteHandlerAdapter {

    private final static Logger log = 
        LoggerFactory.getLogger(UdtRelayFrontendHandler.class);
    private final int remotePort;

    private volatile Channel outboundChannel;

    public UdtRelayFrontendHandler(final int remotePort) {
        this.remotePort = remotePort;
    }

    @Override
    public void channelActive(final ChannelHandlerContext ctx) throws Exception {
        // The idea here is that as soon as we get an incoming channel we 
        // immediately create the outgoing channel. This is because the whole
        // purpose is to relay data.
        log.debug("CHANNEL ACTIVE!!");
        final Channel inboundChannel = ctx.channel();

        // Start the connection attempt.
        final Bootstrap clientBootstrapFromRelayToBackendServer = new Bootstrap();
        clientBootstrapFromRelayToBackendServer.group(inboundChannel.eventLoop())
            .channel(NioSocketChannel.class)
            .handler(new UdtRelayServerBackendHandler(inboundChannel))
            .option(ChannelOption.AUTO_READ, false);
        
        final ChannelFuture cf = 
            clientBootstrapFromRelayToBackendServer.connect(
                LanternClientConstants.LOCALHOST, remotePort);
        outboundChannel = cf.channel();
        cf.addListener(new ChannelFutureListener() {
            @Override
            public void operationComplete(ChannelFuture future) 
                throws Exception {
                if (future.isSuccess()) {
                    log.debug("Outbound channel connected!");
                    // Connection complete start to read first data
                    inboundChannel.read();
                    log.debug("Reading from inbound channel");
                } else {
                    log.warn("Outbound channel connection failed!");
                    // Close the connection if the connection attempt has 
                    // failed.
                    inboundChannel.close();
                }
            }
        });
    }

    @Override
    public void inboundBufferUpdated(final ChannelHandlerContext ctx, 
        final ByteBuf in) throws Exception {
        // Just write incoming bytes to the outgoing connection to the 
        // destination server.
        log.debug("Inbound buffer with bytes: {}", in.readableBytes());
        final ByteBuf out = outboundChannel.outboundByteBuffer();
        out.writeBytes(in);
        if (outboundChannel.isActive()) {
            outboundChannel.flush().addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(final ChannelFuture cf) 
                    throws Exception {
                    if (cf.isSuccess()) {
                        log.debug("Flushed data on outbound connection!!");
                        // Flushed out data - start to read the next chunk
                        ctx.channel().read();
                    } else {
                        log.debug("Failed to flush data?");
                        cf.channel().close();
                    }
                }
            });
        } else {
            log.warn("Outbound handler not active!");
        }
    }

    @Override
    public void channelInactive(final ChannelHandlerContext ctx) 
        throws Exception {
        log.debug("Got an inactive channel: {}", ctx.channel());
        if (outboundChannel != null) {
            log.debug("Closing outbound channel as a result: {}", outboundChannel);
            closeOnFlush(outboundChannel);
        }
    }

    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final Throwable cause) throws Exception {
        cause.printStackTrace();
        log.debug("Closing channel {} after exception", ctx.channel(), cause);
        closeOnFlush(ctx.channel());
    }

    /**
     * Closes the specified channel after all queued write requests are flushed.
     */
    static void closeOnFlush(final Channel ch) {
        log.debug("Closing on flush...dumpting stack");
        if (ch.isActive()) {
            ch.flush().addListener(ChannelFutureListener.CLOSE);
        }
    }
}
