package org.mg.client;

import java.net.InetSocketAddress;
import java.util.concurrent.Executors;

import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.mg.common.MgUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handler that relays traffic to another proxy.
 */
public class ProxyRelayHandler extends SimpleChannelUpstreamHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private volatile long messagesReceived = 0L;

    private final InetSocketAddress proxyAddress;

    private Channel outboundChannel;

    private Channel inboundChannel;

    private final ProxyStatusListener proxyStatusListener;
    
    private final ClientSocketChannelFactory clientSocketChannelFactory =
        new NioClientSocketChannelFactory(
            Executors.newCachedThreadPool(),
            Executors.newCachedThreadPool());

    
    /**
     * Creates a new relayer to a proxy.
     * 
     * @param proxyAddress The address of the proxy.
     * @param clientSocketChannelFactory The factory for creating socket 
     * channels to the proxy.
     * @param proxyStatusListener The class to notify of changes in the proxy
     * status.
     */
    public ProxyRelayHandler(final InetSocketAddress proxyAddress, 
        final ProxyStatusListener proxyStatusListener) {
        // TODO: We also need to handle p2p URIs as addresses here so we
        // can create P2P connections to them.
        this.proxyAddress = proxyAddress;
        this.proxyStatusListener = proxyStatusListener;
    }
    
    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        messagesReceived++;
        log.info("Received {} total messages", messagesReceived);
        this.outboundChannel.write(me.getMessage());
    }
    
    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) {
        if (this.outboundChannel != null) {
            log.error("Outbound channel already assigned?");
        }
        this.inboundChannel = e.getChannel();
        inboundChannel.setReadable(false);

        // Start the connection attempt.
        final ClientBootstrap cb = 
            new ClientBootstrap(this.clientSocketChannelFactory);
        cb.getPipeline().addLast("handler", 
            new OutboundHandler(e.getChannel()));
        final ChannelFuture cf = cb.connect(this.proxyAddress);

        this.outboundChannel = cf.getChannel();
        cf.addListener(new ChannelFutureListener() {
            public void operationComplete(final ChannelFuture future) 
                throws Exception {
                if (future.isSuccess()) {
                    // Connection attempt succeeded:
                    // Begin to accept incoming traffic.
                    inboundChannel.setReadable(true);
                } else {
                    // Close the connection if the connection attempt has failed.
                    inboundChannel.close();
                    proxyStatusListener.onCouldNotConnect(proxyAddress);
                }
            }
        });
    }
    
    @Override 
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) {
        log.info("Got inbound channel closed. Closing outbound.");
        MgUtils.closeOnFlush(this.outboundChannel);
    }
    
    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        log.error("Caught exception on INBOUND channel", e.getCause());
        MgUtils.closeOnFlush(this.inboundChannel);
    }
    
    private static class OutboundHandler extends SimpleChannelUpstreamHandler {

        private final Logger log = LoggerFactory.getLogger(getClass());
        
        private final Channel inboundChannel;

        OutboundHandler(final Channel inboundChannel) {
            this.inboundChannel = inboundChannel;
        }

        @Override
        public void messageReceived(final ChannelHandlerContext ctx, 
            final MessageEvent e) throws Exception {
            final ChannelBuffer msg = (ChannelBuffer) e.getMessage();
            inboundChannel.write(msg);
        }

        @Override
        public void channelClosed(final ChannelHandlerContext ctx, 
            final ChannelStateEvent e) throws Exception {
            MgUtils.closeOnFlush(inboundChannel);
        }

        @Override
        public void exceptionCaught(final ChannelHandlerContext ctx, 
            final ExceptionEvent e) throws Exception {
            log.error("Caught exception on OUTBOUND channel", e.getCause());
            MgUtils.closeOnFlush(e.getChannel());
        }
    }

}
