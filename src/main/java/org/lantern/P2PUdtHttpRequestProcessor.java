package org.lantern;

import io.netty.bootstrap.Bootstrap;
import io.netty.buffer.ByteBuf;
import io.netty.channel.ChannelInboundByteHandlerAdapter;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.udt.UdtChannel;
import io.netty.channel.udt.nio.NioUdtProvider;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.ThreadFactory;

import javax.net.ssl.SSLEngine;

import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.buffer.ChannelBuffer;
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
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.ssl.SslHandler;
import org.jboss.netty.handler.traffic.GlobalTrafficShapingHandler;
import org.lantern.util.Threads;
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

    private InetSocketAddress proxyAddress;

    private final HttpRequestTransformer transformer;

    private final ChannelGroup channelGroup;

    private final Stats stats;

    private final LanternTrustStore trustStore;

    private GlobalTrafficShapingHandler trafficHandler;

    private ProxyHolder proxyHolder;

    public P2PUdtHttpRequestProcessor( 
        final ProxyTracker proxyTracker, 
        final HttpRequestTransformer transformer, 
        final ClientSocketChannelFactory clientSocketChannelFactory,
        final ChannelGroup channelGroup, final Stats stats,
        final LanternTrustStore trustStore) {
        this.proxyTracker = proxyTracker;
        this.transformer = transformer;
        this.clientSocketChannelFactory = clientSocketChannelFactory;
        this.channelGroup = channelGroup;
        this.stats = stats;
        this.trustStore = trustStore;
    }
    
    private boolean hasProxy() {
        if (this.proxyAddress != null) {
            return true;
        }
        final ProxyHolder ph = this.proxyTracker.getProxy();
        
        if (ph != null) {
            this.proxyHolder = ph;
            this.proxyAddress = ph.getIsa();
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
            return false;
        }
        final HttpMethod method = request.getMethod();
        final boolean connect = method == HttpMethod.CONNECT;
        
        if (cf == null) {
            if (connect) {
                cf = openOutgoingConnectChannel(browserToProxyChannel, request);
            } else {
                cf = openOutgoingChannel(browserToProxyChannel, request);
            }
        }
        if (!connect) {
            this.transformer.transform(request, proxyAddress);
            try {
                LanternUtils.writeRequest(this.httpRequests, request, cf);
            } catch (Exception e) {
                return false;
            }
        }
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
        cf.channel().flush().addListener(new io.netty.channel.ChannelFutureListener() {
            
            @Override
            public void operationComplete(io.netty.channel.ChannelFuture future)
                    throws Exception {
                cf.channel().close();
            }
        });
    }

    private io.netty.channel.ChannelFuture openOutgoingChannel(
        final Channel browserToProxyChannel, final HttpRequest request) {
        browserToProxyChannel.setReadable(false);

        final Bootstrap boot = new Bootstrap();
        final ThreadFactory connectFactory = Threads.newThreadFactory("connect");
        final NioEventLoopGroup connectGroup = new NioEventLoopGroup(1,
                connectFactory, NioUdtProvider.BYTE_PROVIDER);

        try {
            boot.group(connectGroup)
                .channelFactory(NioUdtProvider.BYTE_CONNECTOR)
                .handler(new ChannelInitializer<UdtChannel>() {
                    @Override
                    public void initChannel(final UdtChannel ch) 
                        throws Exception {
                        final io.netty.channel.ChannelPipeline p = ch.pipeline();
                        p.addLast(
                            //new LoggingHandler(LogLevel.INFO),
                            new HttpResponseClientHandler(
                                browserToProxyChannel, request));
                    }
                });
            // Start the client.
            return boot.connect(proxyAddress);
        } finally {
            // Shut down the event loop to terminate all threads.
            boot.shutdown();
        }
    }
    
    private io.netty.channel.ChannelFuture openOutgoingConnectChannel(
        final Channel browserToProxyChannel, final HttpRequest request) {
        browserToProxyChannel.setReadable(false);


        final Bootstrap boot = new Bootstrap();
        final ThreadFactory connectFactory = Threads.newThreadFactory("connect");
        final NioEventLoopGroup connectGroup = new NioEventLoopGroup(1,
                connectFactory, NioUdtProvider.BYTE_PROVIDER);

        try {
            boot.group(connectGroup)
                .channelFactory(NioUdtProvider.BYTE_CONNECTOR)
                .handler(new ChannelInitializer<UdtChannel>() {
                    @Override
                    public void initChannel(final UdtChannel ch) 
                        throws Exception {
                        final io.netty.channel.ChannelPipeline p = ch.pipeline();
                        p.addLast(
                            //new LoggingHandler(LogLevel.INFO),
                            new HttpResponseClientHandler(
                                browserToProxyChannel, request));
                    }
                });
            // Start the client.
            return boot.connect(proxyAddress);
        } finally {
            // Shut down the event loop to terminate all threads.
            boot.shutdown();
        }
    }
    
    private void remove(final ChannelPipeline cp, final String name) {
        final ChannelHandler ch = cp.get(name);
        if (ch != null) {
            cp.remove(name);
        }
    }
    
    private ChannelPipeline configureOutgoingPipeline(final ClientBootstrap cb) {
        final ChannelPipeline pipeline = cb.getPipeline();
        
        // It's necessary to use our own engine here, as we need to trust
        // the cert from the proxy.
        final SSLEngine engine = trustStore.getContext().createSSLEngine();
        
        engine.setUseClientMode(true);
        
        final ChannelHandler statsHandler = new StatsTrackingHandler() {
            @Override
            public void addUpBytes(final long bytes) {
                stats.addUpBytesViaProxies(bytes);
            }
            @Override
            public void addDownBytes(final long bytes) {
                stats.addDownBytesViaProxies(bytes);
            }
        };

        // This is slightly odd in the CONNECT case, as we tunnel SSL inside 
        // SSL, but we'd otherwise just be running an open CONNECT proxy.
        pipeline.addLast("trafficHandler", trafficHandler);
        pipeline.addLast("stats", statsHandler);
        pipeline.addLast("ssl", new SslHandler(engine));
        pipeline.addLast("encoder", new HttpRequestEncoder());
        return pipeline;
    }

    private static class HttpResponseClientHandler extends ChannelInboundByteHandlerAdapter {

        private static final Logger log = 
                LoggerFactory.getLogger(HttpResponseClientHandler.class);

        //private final ByteBuf message = Unpooled.wrappedBuffer(REQUEST.getBytes());

        private final Channel browserToProxyChannel;

        private HttpResponseClientHandler(
            final Channel browserToProxyChannel, final HttpRequest request) {
            this.browserToProxyChannel = browserToProxyChannel;
            //this.httpRequest = request;
        }

        @Override
        public void channelActive(final io.netty.channel.ChannelHandlerContext ctx) throws Exception {
            log.info("Channel active " + NioUdtProvider.socketUDT(ctx.channel()).toStringOptions());
            
            //ctx.write(encoder.encode(httpRequest));
        }

        @Override
        public void inboundBufferUpdated(final io.netty.channel.ChannelHandlerContext ctx,
                final ByteBuf in) {
            final String response = in.toString(LanternConstants.UTF8);
            log.info("INBOUND UPDATED!!\n"+response);
            
            
            synchronized (browserToProxyChannel) {
                final ChannelBuffer wrapped = ChannelBuffers.wrappedBuffer(response.getBytes());
                this.browserToProxyChannel.write(wrapped);
                this.browserToProxyChannel.notifyAll();
            }
        }

        @Override
        public void exceptionCaught(final io.netty.channel.ChannelHandlerContext ctx,
                final Throwable cause) {
            log.debug("close the connection when an exception is raised", cause);
            ctx.close();
        }

        @Override
        public ByteBuf newInboundBuffer(final io.netty.channel.ChannelHandlerContext ctx)
                throws Exception {
            log.info("NEW INBOUND BUFFER");
            return ctx.alloc().directBuffer(
                    ctx.channel().config().getOption(ChannelOption.SO_RCVBUF));
        }

    }
}
