package org.lantern;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;

import javax.net.ssl.SSLEngine;

import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandler;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpChunk;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.codec.http.HttpResponseDecoder;
import org.jboss.netty.handler.ssl.SslHandler;
import org.jboss.netty.handler.traffic.GlobalTrafficShapingHandler;
import org.littleshoot.proxy.HttpConnectRelayingHandler;
import org.littleshoot.proxy.ProxyUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class DefaultHttpRequestProcessor implements HttpRequestProcessor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private ChannelFuture cf;
    
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

    private final boolean isLae;

    private final ChannelGroup channelGroup;

    private final Stats stats;

    private final LanternTrustStore trustStore;

    private GlobalTrafficShapingHandler trafficHandler;

    private ProxyHolder proxyHolder;


    public DefaultHttpRequestProcessor( 
        final ProxyTracker proxyTracker, 
        final HttpRequestTransformer transformer, final boolean isLae, 
        final ClientSocketChannelFactory clientSocketChannelFactory,
        final ChannelGroup channelGroup, final Stats stats,
        final LanternTrustStore trustStore) {
        this.proxyTracker = proxyTracker;
        this.transformer = transformer;
        this.isLae = isLae;
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
            this.proxyAddress = ph.getFiveTuple().getRemote();
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
            LanternUtils.writeRequest(this.httpRequests, request, cf);
        }
        return true;
    }
    
    @Override
    public boolean processChunk(final ChannelHandlerContext ctx, 
        final HttpChunk chunk) throws IOException {
        cf.getChannel().write(chunk);
        return true;
    }

    @Override
    public void close() {
        if (cf == null) {
            return;
        }
        ProxyUtils.closeOnFlush(this.cf.getChannel());
    }

    private ChannelFuture openOutgoingChannel(
        final Channel browserToProxyChannel, final HttpRequest request) {
        
        browserToProxyChannel.setReadable(false);
        // Start the connection attempt.
        final ClientBootstrap cb = 
            new ClientBootstrap(clientSocketChannelFactory);
        final ChannelPipeline pipeline = configureOutgoingPipeline(cb);
        
        pipeline.addLast("decoder", new HttpResponseDecoder());
        pipeline.addLast("handler", 
            new ChunkedProxyDownloader(request, browserToProxyChannel, 
                httpRequests, channelGroup));
        
        log.debug("Connecting to proxy at: {}", proxyAddress);
        
        final ChannelFuture connectFuture = cb.connect(proxyAddress);
        
        // This is handy, as set readable to false while the channel is 
        // connecting ensures we won't get any incoming messages until
        // we're fully connected.
        connectFuture.addListener(new ChannelFutureListener() {
            @Override
            public void operationComplete(final ChannelFuture future) 
                throws Exception {
                if (future.isSuccess()) {
                    // Connection attempt succeeded:
                    // Begin to accept incoming traffic.
                    browserToProxyChannel.setReadable(true);
                } else {
                    // Close the connection if the connection attempt has failed.
                    browserToProxyChannel.close();
                    if (isLae) {
                        proxyTracker.onCouldNotConnectToLae(proxyHolder);
                    } else {
                        proxyTracker.onCouldNotConnect(proxyHolder);
                    }
                }
            }
        });
        return connectFuture;
    }
    
    private ChannelFuture openOutgoingConnectChannel(
        final Channel browserToProxyChannel, final HttpRequest request) {
        browserToProxyChannel.setReadable(false);

        // Start the connection attempt.
        final ClientBootstrap cb = 
            new ClientBootstrap(clientSocketChannelFactory);
        
        final ChannelPipeline pipeline = configureOutgoingPipeline(cb);
        
        pipeline.addLast("handler", 
            new HttpConnectRelayingHandler(browserToProxyChannel, 
                this.channelGroup));
        log.debug("Connecting to relay proxy {} for {}", proxyAddress, request.getUri());
        final ChannelFuture connectFuture = cb.connect(proxyAddress);
        log.debug("Got an outbound channel on: {}", hashCode());
        
        final ChannelPipeline browserPipeline = 
            browserToProxyChannel.getPipeline();
        remove(browserPipeline, "encoder");
        remove(browserPipeline, "decoder");
        remove(browserPipeline, "handler");
        remove(browserPipeline, "encoder");
        browserPipeline.addLast("handler", 
            new HttpConnectRelayingHandler(connectFuture.getChannel(), 
                this.channelGroup));
        
        // This is handy, as set readable to false while the channel is 
        // connecting ensures we won't get any incoming messages until
        // we're fully connected.
        connectFuture.addListener(new ChannelFutureListener() {
            @Override
            public void operationComplete(final ChannelFuture future) 
                throws Exception {
                if (future.isSuccess()) {
                    connectFuture.getChannel().write(request).addListener(
                        new ChannelFutureListener() {
                            @Override
                            public void operationComplete(
                                final ChannelFuture channelFuture) 
                                throws Exception {
                                // we're using HTTP connect here, so we need
                                // to remove the encoder and start reading
                                // from the inbound channel only when we've
                                // used the original encoder to properly encode
                                // the CONNECT request.
                                pipeline.remove("encoder");
                                
                                // Begin to accept incoming traffic.
                                browserToProxyChannel.setReadable(true);
                            }
                    });
                    
                } else {
                    // Close the connection if the connection attempt has failed.
                    browserToProxyChannel.close();
                    proxyTracker.onCouldNotConnect(proxyHolder);
                }
            }
        });
        
        return connectFuture;
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

}
