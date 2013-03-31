package org.lantern;

import java.net.InetSocketAddress;

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
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.ssl.SslHandler;
import org.lantern.util.LanternTrafficCounter;
import org.lantern.util.Netty3LanternTrafficCounterHandler;
import org.littleshoot.proxy.HttpConnectRelayingHandler;
import org.littleshoot.proxy.ProxyUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * HTTP request processor for handling requests being sent to TCP endpoints.
 * Note that this class simply handles the first request and then relays
 * traffic in both directions with decoding requests or responses.
 */
public class TcpHttpRequestProcessor implements HttpRequestProcessor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private ChannelFuture cf;
    
    private final ClientSocketChannelFactory clientSocketChannelFactory;

    private final ProxyTracker proxyTracker;

    private InetSocketAddress proxyAddress;

    private final ChannelGroup channelGroup;

    private final Stats stats;

    private final LanternTrustStore trustStore;

    private LanternTrafficCounter trafficHandler;

    private ProxyHolder proxyHolder;

    public TcpHttpRequestProcessor( 
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
        log.debug("No proxy!");
        return false;
    }

    @Override
    public boolean processRequest(final Channel browserToProxyChannel,
        final ChannelHandlerContext ctx, final HttpRequest request) {
        if (!hasProxy()) {
            log.debug("No proxy?");
            return false;
        }
        cf = openOutgoingChannel(browserToProxyChannel, request);
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
        
        final ChannelPipeline pipeline = cb.getPipeline();
        
        // It's necessary to use our own engine here, as we need to trust
        // the cert from the proxy.
        final SSLEngine engine = trustStore.getClientContext().createSSLEngine();
        engine.setUseClientMode(true);
        
        if (trafficHandler != null) {
            if( trafficHandler instanceof Netty3LanternTrafficCounterHandler) {
                pipeline.addLast("trafficHandler", 
                    (Netty3LanternTrafficCounterHandler)trafficHandler);
            } else{
                log.error("Not a GlobalTrafficShapingHandler??? "+
                    trafficHandler.getClass());
            }
        }
        
        // Could be null for testing.
        if (stats != null) {
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
    
            pipeline.addLast("stats", statsHandler);
        }
        
        // This is slightly odd in the CONNECT case, as we tunnel SSL inside 
        // SSL, but we'd otherwise just be running an open CONNECT proxy.
        pipeline.addLast("ssl", new SslHandler(engine));
        pipeline.addLast("encoder", new HttpRequestEncoder());
        
        pipeline.addLast("handler", 
            new HttpConnectRelayingHandler(browserToProxyChannel, 
                this.channelGroup));
        log.debug("Connecting to relay proxy {} for {}", proxyAddress, 
            request.getUri());
        final ChannelFuture connectFuture = cb.connect(proxyAddress);
        log.debug("Created outbound channel for processor: {}", hashCode());
        
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
}
