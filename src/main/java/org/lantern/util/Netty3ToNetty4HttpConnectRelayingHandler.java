package org.lantern.util;

import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandler.Sharable;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.ChannelGroup;
import org.lantern.LanternUtils;
import org.littleshoot.proxy.ProxyUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class that simply relays traffic the channel this is connected to to 
 * another channel passed in to the constructor.
 */
@Sharable
public class Netty3ToNetty4HttpConnectRelayingHandler 
    extends SimpleChannelUpstreamHandler {
    
    private static final Logger LOG = 
        LoggerFactory.getLogger(Netty3ToNetty4HttpConnectRelayingHandler.class);
    
    /**
     * The channel to relay to. This could be a connection from the browser
     * to the proxy or it could be a connection from the proxy to an external
     * site.
     */
    private final io.netty.channel.Channel netty4RelayChannel;

    private final ChannelGroup channelGroup;

    /**
     * Creates a new {@link Netty3ToNetty4HttpConnectRelayingHandler} with the 
     * specified connection to relay to.
     * 
     * @param netty4Channel The channel to relay messages to.
     * @param channelGroup The group of channels to close on shutdown.
     */
    public Netty3ToNetty4HttpConnectRelayingHandler(
        final io.netty.channel.Channel netty4Channel, 
        final ChannelGroup channelGroup) {
        // Fail fast if these are null.
        if (netty4Channel == null) {
            throw new NullPointerException("Relay channel is null!");
        }
        if (channelGroup == null) {
            throw new NullPointerException("Channel group is null!!");
        }
        this.netty4RelayChannel = netty4Channel;
        this.channelGroup = channelGroup;
    }

    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent e) throws Exception {
        final ChannelBuffer msg = (ChannelBuffer) e.getMessage();
        if (netty4RelayChannel.isOpen()) {
            final io.netty.channel.ChannelFutureListener logListener = 
                new io.netty.channel.ChannelFutureListener() {
                    @Override
                    public void operationComplete(
                        final io.netty.channel.ChannelFuture cf)
                        throws Exception {
                        LOG.debug("Finished writing data on CONNECT channel");
                    }
                };
            netty4RelayChannel.write(LanternUtils.channelBufferToByteBuf(msg)).addListener(logListener);
        }
        else {
            LOG.debug("Channel not open. Connected? {}", netty4RelayChannel.isOpen());
            // This will undoubtedly happen anyway, but just in case.
            ProxyUtils.closeOnFlush(e.getChannel());
        }
    }
    
    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent cse) throws Exception {
        final Channel ch = cse.getChannel();
        LOG.debug("New CONNECT channel opened from proxy to web: {}", ch);
        this.channelGroup.add(ch);
    }

    @Override
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) throws Exception {
        LOG.debug("Got closed event on proxy -> web connection: {}", 
            e.getChannel());
        this.netty4RelayChannel.close();
    }

    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        LOG.debug("Caught exception on proxy -> web connection: "+
            e.getChannel(), e.getCause());
        ProxyUtils.closeOnFlush(e.getChannel());
    }
}
