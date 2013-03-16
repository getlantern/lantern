package org.lantern;

import io.netty.bootstrap.Bootstrap;
import io.netty.buffer.ByteBuf;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.udt.UdtChannel;
import io.netty.channel.udt.nio.NioUdtProvider;
import io.netty.handler.ssl.SslHandler;

import java.util.concurrent.ThreadFactory;

import javax.net.ssl.SSLEngine;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandler;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.lantern.util.LanternTrafficCounter;
import org.lantern.util.Netty3ToNetty4HttpConnectRelayingHandler;
import org.lantern.util.Netty4LanternTrafficCounterHandler;
import org.lantern.util.NettyUtils;
import org.lantern.util.Threads;
import org.littleshoot.util.FiveTuple;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * HTTP request processor that uses Netty 4 to communicate with a UDT socket
 * on a remote peer.
 */
public class UdtHttpRequestProcessor implements HttpRequestProcessor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private io.netty.channel.ChannelFuture cf;
    
    private final ProxyTracker proxyTracker;

    private FiveTuple fiveTuple;

    private final ChannelGroup channelGroup;

    private final Stats stats;

    private final LanternTrustStore trustStore;

    private LanternTrafficCounter trafficHandler;

    private ProxyHolder proxyHolder;

    private final Bootstrap clientBootstrap = new Bootstrap();

    public UdtHttpRequestProcessor( 
        final ProxyTracker proxyTracker, 
        final ChannelGroup channelGroup, final Stats stats,
        final LanternTrustStore trustStore) {
        this.proxyTracker = proxyTracker;
        this.channelGroup = channelGroup;
        this.stats = stats;
        this.trustStore = trustStore;
    }
    
    private boolean hasProxy() {
        if (this.fiveTuple != null) {
            return true;
        }
        final ProxyHolder ph = this.proxyTracker.getJidProxy();
        
        if (ph != null) {
            this.proxyHolder = ph;
            this.fiveTuple = ph.getFiveTuple();
            this.trafficHandler = ph.getTrafficShapingHandler();
            return true;
        }
        log.info("No proxy!");
        return false;
    }

    @Override
    public boolean processRequest(final Channel browserToProxyChannel,
        final ChannelHandlerContext ctx, final HttpRequest request) {
        if (!hasProxy()) {
            log.debug("No proxy!!");
            return false;
        }
        log.debug("Processing request...");
        // Note we're able to just create this simple channel for both CONNECT
        // and "normal" requests because we remove all encoders and decoders
        // after the initial request on the connection and just relay in 
        // both directions thereafter.
        if (cf == null) {
            cf = openOutgoingChannel(browserToProxyChannel, request);
        }
        return true;
    }

    @Override
    public void close() {
        if (cf == null) {
            return;
        }
        NettyUtils.closeOnFlush(cf.channel());
        this.clientBootstrap.shutdown();
    }
    
    private void remove(final ChannelPipeline cp, final String name) {
        final ChannelHandler ch = cp.get(name);
        if (ch != null) {
            cp.remove(name);
        }
    }

    /**
     * Opens an outgoing channel to the destination proxy. Note we use this
     * for both normal requests as well as HTTP CONNECT requests, as we
     * remove all the encoders and decoders from both incoming and outgoing 
     * channels and just act as a relay after the initial first request.
     * Note that it is possible for a requester to call HTTP CONNECT in the
     * middle of a persistent HTTP 1.1 connection, potentially causing 
     * issues for remote proxies that don't support CONNECT, but in 
     * practice this will rarely if ever happen.
     * 
     * @param browserToProxyChannel The clinet channel
     * @param request The request
     * @return The future for connecting to the destination site.
     */
    private ChannelFuture openOutgoingChannel(
        final Channel browserToProxyChannel, final HttpRequest request) {
        browserToProxyChannel.setReadable(false);
        
        final ThreadFactory connectFactory = 
            Threads.newNonDaemonThreadFactory("connect");
        final NioEventLoopGroup connectGroup = new NioEventLoopGroup(1,
                connectFactory, NioUdtProvider.BYTE_PROVIDER);

        this.clientBootstrap.group(connectGroup)
            .channelFactory(NioUdtProvider.BYTE_CONNECTOR)
            .option(ChannelOption.SO_REUSEADDR, true)
            .handler(new ChannelInitializer<UdtChannel>() {
                @Override
                public void initChannel(final UdtChannel ch)
                        throws Exception {
                    final io.netty.channel.ChannelPipeline p = ch.pipeline();
                    
                    if (trafficHandler != null) {
                        if (trafficHandler instanceof Netty4LanternTrafficCounterHandler) {
                            p.addLast("trafficHandler", 
                                (Netty4LanternTrafficCounterHandler)trafficHandler);
                        } else{
                            log.error("Not a GlobalTrafficShapingHandler??? "+
                                    trafficHandler.getClass());
                        }
                    }
                    
                    final SSLEngine engine = 
                        trustStore.getContext().createSSLEngine();
                    engine.setUseClientMode(true);
                    p.addLast("ssl", new SslHandler(engine));
                    p.addLast(
                        //new LoggingHandler(LogLevel.INFO),
                        new HttpResponseClientHandler(browserToProxyChannel));
                }
            });
        // Start the client.
        final ChannelFuture connectFuture = 
            this.clientBootstrap.connect(this.fiveTuple.getRemote(), 
                this.fiveTuple.getLocal());
        
        final ChannelPipeline browserPipeline = 
            browserToProxyChannel.getPipeline();
        remove(browserPipeline, "encoder");
        remove(browserPipeline, "decoder");
        remove(browserPipeline, "handler");
        remove(browserPipeline, "encoder");
        browserPipeline.addLast("handler", 
            new Netty3ToNetty4HttpConnectRelayingHandler(connectFuture.channel(), 
                channelGroup));
        
        connectFuture.addListener(new ChannelFutureListener() {
            
            @Override
            public void operationComplete(final ChannelFuture future) throws Exception {
                if (future.isSuccess()) {
                    future.channel().write(NettyUtils.encoder.encode(request));
                    // we're using HTTP connect here, so we need
                    // to remove the encoder and start reading
                    // from the inbound channel only when we've
                    // used the original encoder to properly encode
                    // the CONNECT request.
                    //destinationConnect.remove("encoder");
                    
                    // Begin to accept incoming traffic.
                    browserToProxyChannel.setReadable(true);
                } else {
                    browserToProxyChannel.close();
                    proxyTracker.onCouldNotConnect(proxyHolder);
                }
            }
        });
        return connectFuture;
    }
    
    private static class HttpResponseClientHandler 
        extends io.netty.channel.ChannelInboundByteHandlerAdapter {

        private static final Logger log = 
                LoggerFactory.getLogger(HttpResponseClientHandler.class);

        private final Channel browserToProxyChannel;

        private HttpResponseClientHandler(final Channel browserToProxyChannel) {
            this.browserToProxyChannel = browserToProxyChannel;
        }

        @Override
        public void channelActive(
            final io.netty.channel.ChannelHandlerContext ctx) throws Exception {
            log.debug("Channel active " + 
               NioUdtProvider.socketUDT(ctx.channel()).toStringOptions());
        }

        @Override
        public void inboundBufferUpdated(
            final io.netty.channel.ChannelHandlerContext ctx, final ByteBuf in) {
            NettyUtils.copyByteBufToChannel(in, this.browserToProxyChannel);
        }

        @Override
        public void exceptionCaught(final io.netty.channel.ChannelHandlerContext ctx,
                final Throwable cause) {
            log.debug("close the connection when an exception is raised", cause);
            ctx.close();
        }

        @Override
        public ByteBuf newInboundBuffer(
            final io.netty.channel.ChannelHandlerContext ctx) throws Exception {
            log.debug("NEW INBOUND BUFFER");
            return ctx.alloc().directBuffer(
                    ctx.channel().config().getOption(ChannelOption.SO_RCVBUF));
        }

    }
}
