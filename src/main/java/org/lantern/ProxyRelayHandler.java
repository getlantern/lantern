package org.lantern;

import java.net.InetSocketAddress;
import java.util.concurrent.Executors;

import javax.net.ssl.SSLEngine;

import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.handler.ssl.SslHandler;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.proxy.ProxyUtils;
import org.littleshoot.proxy.SslContextFactory;
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

    private final KeyStoreManager keyStoreManager;

    
    /**
     * Creates a new relayer to a proxy.
     * 
     * @param proxyAddress The address of the proxy.
     * @param clientSocketChannelFactory The factory for creating socket 
     * channels to the proxy.
     * @param proxyStatusListener The class to notify of changes in the proxy
     * status.
     * @param keyStoreManager Determines whether the proxy should be trusted.
     * This can be <code>null</code> in some cases.
     */
    public ProxyRelayHandler(final InetSocketAddress proxyAddress, 
        final ProxyStatusListener proxyStatusListener, 
        final KeyStoreManager keyStoreManager) {
        this.proxyAddress = proxyAddress;
        this.proxyStatusListener = proxyStatusListener;
        this.keyStoreManager = keyStoreManager;
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
        
        final ChannelPipeline pipeline = cb.getPipeline();
        
        if (this.keyStoreManager != null) {
            log.info("Adding SSL for client connection");
            final SslContextFactory sslFactory = 
                new SslContextFactory(this.keyStoreManager);
            final SSLEngine engine =
                sslFactory.getClientContext().createSSLEngine();
            engine.setUseClientMode(true);
            pipeline.addLast("ssl", new SslHandler(engine));
        }
        
        pipeline.addLast("handler", 
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
        ProxyUtils.closeOnFlush(this.outboundChannel);
    }
    
    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        log.error("Caught exception on INBOUND channel", e.getCause());
        ProxyUtils.closeOnFlush(this.inboundChannel);
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
            ProxyUtils.closeOnFlush(inboundChannel);
        }

        @Override
        public void exceptionCaught(final ChannelHandlerContext ctx, 
            final ExceptionEvent e) throws Exception {
            log.error("Caught exception on OUTBOUND channel", e.getCause());
            ProxyUtils.closeOnFlush(e.getChannel());
        }
    }

}
