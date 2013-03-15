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
import io.netty.handler.traffic.GlobalTrafficShapingHandler;

import java.io.IOException;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.ThreadFactory;

import javax.net.ssl.SSLEngine;

import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandler;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpChunk;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.lantern.util.Netty3ToNetty4HttpConnectRelayingHandler;
import org.lantern.util.Threads;
import org.littleshoot.util.FiveTuple;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class P2PUdtHttpRequestProcessor implements HttpRequestProcessor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private io.netty.channel.ChannelFuture cf;
    
    private final ClientSocketChannelFactory clientSocketChannelFactory;

    /**
     * These need to be synchronized with HTTP responses in the case where we
     * need to issue multiple HTTP range requests in response to 206 responses.
     * This is particularly relevant for LAE because of response size limits.
     */
    private final Queue<HttpRequest> httpRequests = 
        new ConcurrentLinkedQueue<HttpRequest>();

    private final ProxyTracker proxyTracker;

    private FiveTuple fiveTuple;

    private final ChannelGroup channelGroup;

    private final Stats stats;

    private final LanternTrustStore trustStore;

    private GlobalTrafficShapingHandler trafficHandler;

    private ProxyHolder proxyHolder;

    private final Bootstrap clientBootstrap = new Bootstrap();

    public P2PUdtHttpRequestProcessor( 
        final ProxyTracker proxyTracker, 
        final ClientSocketChannelFactory clientSocketChannelFactory,
        final ChannelGroup channelGroup, final Stats stats,
        final LanternTrustStore trustStore) {
        this.proxyTracker = proxyTracker;
        this.clientSocketChannelFactory = clientSocketChannelFactory;
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
            //this.trafficHandler = ph.getTrafficShapingHandler();
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
        final HttpMethod method = request.getMethod();
        final boolean connect = method == HttpMethod.CONNECT;
        
        if (cf == null) {
            if (connect) {
                cf = openOutgoingConnectChannel(browserToProxyChannel, request);
            } else {
                try {
                    cf = openOutgoingChannel(browserToProxyChannel);
                    cf.channel().write(LanternUtils.encoder.encode(request)).sync();
                } catch (final Exception e) {
                    log.error("Could not connect?", e);
                    return false;
                }
            }
        }
        /*
        if (!connect) {
            try {
                LanternUtils.writeRequest(request, cf);
            } catch (Exception e) {
                return false;
            }
        }
        */
        return true;
    }
    
    @Override
    public boolean processChunk(final ChannelHandlerContext ctx, 
        final HttpChunk chunk) throws IOException {
        try {
            cf.channel().write(LanternUtils.encoder.encode(chunk));
            return true;
        } catch (final Exception e) {
            throw new IOException("Could not write chunk?", e);
        }
    }

    @Override
    public void close() {
        if (cf == null) {
            return;
        }
        LanternUtils.closeOnFlush(cf.channel());
        this.clientBootstrap.shutdown();
    }
    
    private void remove(final ChannelPipeline cp, final String name) {
        final ChannelHandler ch = cp.get(name);
        if (ch != null) {
            cp.remove(name);
        }
    }
    
    private ChannelFuture openOutgoingChannel(
        final Channel browserToProxyChannel) throws InterruptedException {
        browserToProxyChannel.setReadable(false);
        
        final ThreadFactory connectFactory = Threads.newThreadFactory("connect");
        final NioEventLoopGroup connectGroup = new NioEventLoopGroup(1,
                connectFactory, NioUdtProvider.BYTE_PROVIDER);

        clientBootstrap.group(connectGroup)
            .channelFactory(NioUdtProvider.BYTE_CONNECTOR)
            .option(ChannelOption.SO_REUSEADDR, true)
            .handler(new ChannelInitializer<UdtChannel>() {
                @Override
                public void initChannel(final UdtChannel ch)
                        throws Exception {
                    final io.netty.channel.ChannelPipeline p = ch.pipeline();
                    final SSLEngine engine = 
                        trustStore.getContext().createSSLEngine();
                    engine.setUseClientMode(true);
                    p.addLast("ssl", new SslHandler(engine));
                    p.addLast(
                        //new LoggingHandler(LogLevel.INFO),
                        new HttpResponseClientHandler(browserToProxyChannel));
                }
            });
        
        log.debug("Connecting to {}", this.fiveTuple);
        // Start the client.
        final ChannelFuture f = 
            clientBootstrap.connect(this.fiveTuple.getRemote(), 
                this.fiveTuple.getLocal()).sync();
        log.debug("Opened outgoing channel");
        
        return f;

    }
    

    private ChannelFuture openOutgoingConnectChannel(
        final Channel browserToProxyChannel, final HttpRequest request) {
        browserToProxyChannel.setReadable(false);
        
        final ThreadFactory connectFactory = Threads.newThreadFactory("connect");
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
                    final SSLEngine engine = 
                        trustStore.getContext().createSSLEngine();
                    engine.setUseClientMode(true);
                    p.addLast("ssl", new SslHandler(engine));
                    p.addLast(
                        //new LoggingHandler(LogLevel.INFO),
                        new HttpResponseClientHandler(browserToProxyChannel));
                }
            });
        /*
        try {
            boot.bind(ft.getLocal()).sync();
        } catch (final InterruptedException e) {
            log.error("Could not sync on bind? Reuse address no working?", e);
        }
        */
        // Start the client.
        final ChannelFuture destinationConnect = 
            this.clientBootstrap.connect(this.fiveTuple.getRemote(), 
                this.fiveTuple.getLocal());
        
        final ChannelPipeline browserPipeline = 
            browserToProxyChannel.getPipeline();
        remove(browserPipeline, "encoder");
        remove(browserPipeline, "decoder");
        remove(browserPipeline, "handler");
        remove(browserPipeline, "encoder");
        browserPipeline.addLast("handler", 
            new Netty3ToNetty4HttpConnectRelayingHandler(cf.channel(), 
                this.channelGroup));
        
        destinationConnect.addListener(new ChannelFutureListener() {
            
            @Override
            public void operationComplete(final ChannelFuture future) throws Exception {
                if (future.isSuccess()) {
                    future.channel().write(LanternUtils.encoder.encode(request));
                    // we're using HTTP connect here, so we need
                    // to remove the encoder and start reading
                    // from the inbound channel only when we've
                    // used the original encoder to properly encode
                    // the CONNECT request.
                    //destinationConnect.remove("encoder");
                    
                    // Begin to accept incoming traffic.
                    browserToProxyChannel.setReadable(true);
                }
            }
        });
        return destinationConnect;
        // Wait until the connection is closed.
        //f.channel().close();
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
            final byte[] data = new byte[in.readableBytes()];
            in.readBytes(data);
            this.browserToProxyChannel.write(
                    ChannelBuffers.wrappedBuffer(data));
            /*
            while (in.isReadable()) {
                this.browserToProxyChannel.write(
                    ChannelBuffers.wrappedBuffer(new byte[]{in.readByte()}));
            }
            */
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
