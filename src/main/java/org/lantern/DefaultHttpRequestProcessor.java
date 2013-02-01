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
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.codec.http.HttpResponseDecoder;
import org.jboss.netty.handler.ssl.SslHandler;
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

    private final ProxyStatusListener proxyStatusListener;

    private InetSocketAddress proxyAddress;

    private final HttpRequestTransformer transformer;

    private final boolean isLae;

    private final Proxy proxy;

    private final ChannelGroup channelGroup;

    private final Stats stats;

    private final LanternClientSslContextFactory sslFactory;

    public DefaultHttpRequestProcessor( 
        final ProxyStatusListener proxyStatusListener, 
        final HttpRequestTransformer transformer, final boolean isLae, 
        final Proxy proxy, 
        final ClientSocketChannelFactory clientSocketChannelFactory,
        final ChannelGroup channelGroup, final Stats stats,
        final LanternClientSslContextFactory sslFactory) {
        this.proxyStatusListener = proxyStatusListener;
        this.transformer = transformer;
        this.isLae = isLae;
        this.proxy = proxy;
        this.clientSocketChannelFactory = clientSocketChannelFactory;
        this.channelGroup = channelGroup;
        this.stats = stats;
        this.sslFactory = sslFactory;
    }
    
    private boolean hasProxy() {
        if (this.proxyAddress != null) {
            return true;
        }
        this.proxyAddress = this.proxy.getProxy();
        if (this.proxyAddress != null) {
            return true;
        }
        return false;
    }

    @Override
    public boolean processRequest(final Channel browserToProxyChannel,
        final ChannelHandlerContext ctx, final MessageEvent me) {
        if (!hasProxy()) {
            return false;
        }
        final HttpRequest request = (HttpRequest) me.getMessage();
        if (cf == null) {
            cf = openOutgoingChannel(browserToProxyChannel, request);
        }
        this.transformer.transform(request, proxyAddress);
        LanternUtils.writeRequest(this.httpRequests, request, cf);
        return true;
    }

    @Override
    public boolean processChunk(final ChannelHandlerContext ctx, 
        final MessageEvent me) throws IOException {
        cf.getChannel().write(me.getMessage());
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
        final SSLEngine engine;
        
        engine = sslFactory.getClientContext().createSSLEngine();
        /*
        if (this.isLae) {
            log.info("Creating standard SSL engine");
            final LanternClientSslContextFactory sslFactory =
                new LanternClientSslContextFactory(this.ksm);
            engine = sslFactory.getClientContext().createSSLEngine();
        }
        else {
            log.info("Creating Lantern SSL engine");
            final LanternClientSslContextFactory sslFactory =
                new LanternClientSslContextFactory(this.ksm);
            engine = sslFactory.getClientContext().createSSLEngine();
        }
        */
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

        pipeline.addLast("stats", statsHandler);        
        pipeline.addLast("ssl", new SslHandler(engine));
        pipeline.addLast("decoder", new HttpResponseDecoder());
        pipeline.addLast("encoder", new HttpRequestEncoder());
        pipeline.addLast("handler", 
            new ChunkedProxyDownloader(request, browserToProxyChannel, 
                httpRequests, channelGroup));
        //this.proxyHost = proxyAddress.getHostName();
        
        log.info("Connecting to proxy at: {}", proxyAddress);
        
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
                        proxyStatusListener.onCouldNotConnectToLae(proxyAddress);
                    } else {
                        proxyStatusListener.onCouldNotConnect(proxyAddress);
                    }
                }
            }
        });
        return connectFuture;
    }
}
