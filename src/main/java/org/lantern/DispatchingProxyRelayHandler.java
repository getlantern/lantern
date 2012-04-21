package org.lantern;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.URI;
import java.util.concurrent.Executors;

import javax.net.ssl.SSLEngine;

import org.apache.commons.lang.StringUtils;
import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandler;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.DefaultChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.handler.codec.http.DefaultHttpResponse;
import org.jboss.netty.handler.codec.http.HttpChunk;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpHeaders.Names;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.codec.http.HttpResponse;
import org.jboss.netty.handler.codec.http.HttpResponseStatus;
import org.jboss.netty.handler.codec.http.HttpVersion;
import org.jboss.netty.handler.ssl.SslHandler;
import org.littleshoot.proxy.DefaultRelayPipelineFactoryFactory;
import org.littleshoot.proxy.HttpConnectRelayingHandler;
import org.littleshoot.proxy.HttpFilter;
import org.littleshoot.proxy.HttpRequestHandler;
import org.littleshoot.proxy.HttpResponseFilters;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.proxy.ProxyUtils;
import org.littleshoot.proxy.RelayPipelineFactoryFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handler that relays traffic to another proxy, dispatching between 
 * appropriate proxies depending on the type of request.
 */
public class DispatchingProxyRelayHandler extends SimpleChannelUpstreamHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private volatile long messagesReceived = 0L;

    /**
     * Outgoing channel that handles incoming HTTP Connect requests.
     */
    private ChannelFuture httpConnectChannelFuture;
    
    private Channel browserToProxyChannel;

    // http://code.google.com/appengine/docs/quotas.html:
    // "Each incoming HTTP request can be no larger than 32MB"
    private static final long REQUEST_SIZE_LIMIT = 1024 * 1024 * 32 - 4096;

    private static final boolean PROXIES_ACTIVE = LanternHub.settings().isUseCentralProxies();
    private static final boolean ANONYMOUS_ACTIVE = LanternHub.settings().isUseAnonymousPeers();
    private static final boolean TRUSTED_ACTIVE = LanternHub.settings().isUseTrustedPeers();
    private static final boolean LAE_ACTIVE = LanternHub.settings().isUseLaeProxies();
    
    private static final ClientSocketChannelFactory clientSocketChannelFactory =
        new NioClientSocketChannelFactory(
            Executors.newCachedThreadPool(),
            Executors.newCachedThreadPool());
    
    static {
        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
            @Override
            public void run() {
                //clientSocketChannelFactory.releaseExternalResources();
            }
        }));
    }
    
    private final HttpRequestProcessor unproxiedRequestProcessor = 
        new HttpRequestProcessor() {
            final RelayPipelineFactoryFactory pf = 
                new DefaultRelayPipelineFactoryFactory(null, 
                    new HttpResponseFilters() {
                        @Override
                        public HttpFilter getFilter(String arg0) {
                            return null;
                        }
                    }, null, 
                    new DefaultChannelGroup("HTTP-Proxy-Server"));
            private final HttpRequestHandler requestHandler =
                new HttpRequestHandler(clientSocketChannelFactory, pf);
            
            @Override
            public boolean processRequest(final Channel browserChannel,
                final ChannelHandlerContext ctx, final MessageEvent me) 
                throws IOException {
                requestHandler.messageReceived(ctx, me);
                return true;
            }

            @Override
            public boolean processChunk(final ChannelHandlerContext ctx, 
                final MessageEvent me) throws IOException {
                requestHandler.messageReceived(ctx, me);
                return true;
            }
            @Override
            public void close() {
            }
        };
    
    
    private final HttpRequestProcessor proxyRequestProcessor;
    
    //private final HttpRequestProcessor anonymousPeerRequestProcessor;
    
    //private final HttpRequestProcessor trustedPeerRequestProcessor;
    
    private final HttpRequestProcessor laeRequestProcessor;
    
    private HttpRequestProcessor currentRequestProcessor;

    private boolean readingChunks;

    /**
     * Specifies whether or not we're currently proxying requests. This is 
     * necessary because we don't have all the initial HTTP request data,
     * such as the referer or the URI, when we're processing HTTP chunks.
     */
    private boolean proxying;

    private final KeyStoreManager keyStoreManager;

    /**
     * Creates a new handler that reads incoming HTTP requests and dispatches
     * them to proxies as appropriate.
     * 
     * @param keyStoreManager Keeps track of all trusted keys. 
     */
    public DispatchingProxyRelayHandler(final KeyStoreManager keyStoreManager) {
        //this.proxyProvider = proxyProvider;
        //this.proxyStatusListener = proxyStatusListener;
        this.keyStoreManager = keyStoreManager;
        
        // This uses the raw p2p client because all traffic sent over these
        // connections already uses end-to-end encryption.
        /*
        this.anonymousPeerRequestProcessor =
            new PeerHttpConnectRequestProcessor(new Proxy() {
                @Override
                public InetSocketAddress getProxy() {
                    throw new UnsupportedOperationException(
                        "Peer proxy required");
                }
                @Override
                public URI getPeerProxy() {
                    // For CONNECT we can use either an anonymous peer or a
                    // trusted peer.
                    final URI lantern = proxyProvider.getAnonymousProxy();
                    if (lantern == null) {
                        return proxyProvider.getPeerProxy();
                    }
                    return lantern;
                }
            },  proxyStatusListener, encryptingP2pClient);
        
        this.trustedPeerRequestProcessor =
            new PeerHttpRequestProcessor(new Proxy() {
                @Override
                public InetSocketAddress getProxy() {
                    throw new UnsupportedOperationException(
                        "Peer proxy required");
                }
                @Override
                public URI getPeerProxy() {
                    return proxyProvider.getPeerProxy();
                }
            },  proxyStatusListener, encryptingP2pClient, this.keyStoreManager);
        */
        this.proxyRequestProcessor =
            new DefaultHttpRequestProcessor(LanternHub.getProxyStatusListener(),
                new HttpRequestTransformer() {
                    @Override
                    public void transform(final HttpRequest request, 
                        final InetSocketAddress proxyAddress) {
                        // Does nothing.
                    }
                }, false,
                new Proxy() {
                    @Override
                    public URI getPeerProxy() {
                        throw new UnsupportedOperationException(
                            "Peer proxy not supported here.");
                    }
                    @Override
                    public InetSocketAddress getProxy() {
                        return LanternHub.getProxyProvider().getProxy();
                    }
                }, this.keyStoreManager);
        this.laeRequestProcessor =
            new DefaultHttpRequestProcessor(LanternHub.getProxyStatusListener(),
                new LaeHttpRequestTransformer(), true,
                new Proxy() {
                    @Override
                    public URI getPeerProxy() {
                        throw new UnsupportedOperationException(
                            "Peer proxy not supported here.");
                    }
                    @Override
                    public InetSocketAddress getProxy() {
                        return LanternHub.getProxyProvider().getLaeProxy();
                    }
            }, null);
    }

    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        messagesReceived++;
        log.info("Received {} total messages", messagesReceived);
        if (!readingChunks) {
            log.info("Reading HTTP request (not a chunk)...");
            this.currentRequestProcessor = dispatchRequest(ctx, me);
        } 
        else {
            log.info("Reading chunks...");
            try {
                final HttpChunk chunk = (HttpChunk) me.getMessage();
                
                // Remember this will typically be a persistent connection, 
                // so we'll get another request after we're read the last 
                // chunk. So we need to reset it back to no longer read in 
                // chunk mode.
                if (chunk.isLast()) {
                    this.readingChunks = false;
                }
                this.currentRequestProcessor.processChunk(ctx, me);
            } catch (final IOException e) {
                // Unclear what to do here. If we couldn't connect to a remote
                // peer, for example, we don't want to close the connection
                // to the browser. If the other end closed the connection,
                // it could have been due to connection close rules, or it
                // could have been because they simply went offline.
                log.info("Exception processing chunk", e);
            }
        }
        log.info("Done processing HTTP request....");
    }
    
    private HttpRequestProcessor dispatchRequest(
        final ChannelHandlerContext ctx, final MessageEvent me) {
        final HttpRequest request = (HttpRequest)me.getMessage();
        final String uri = request.getUri();
        log.info("URI is: {}", uri);
        
        // We need to set this outside of proxying rules because we first
        // send incoming messages down chunked versus unchunked paths and
        // then send them down proxied versus unproxied paths.
        if (request.isChunked()) {
            readingChunks = true;
        } else {
            readingChunks = false;
        }
        
        this.proxying = LanternUtils.shouldProxy(request);
        
        if (proxying) {
            // If it's an HTTP request, see if we can redirect it to HTTPS.
            final String https = LanternHub.httpsEverywhere().toHttps(uri);
            if (!https.equals(uri)) {
                final HttpResponse response = 
                    new DefaultHttpResponse(request.getProtocolVersion(), 
                        HttpResponseStatus.MOVED_PERMANENTLY);
                response.setProtocolVersion(HttpVersion.HTTP_1_0);
                response.setHeader(HttpHeaders.Names.LOCATION, https);
                response.setHeader(HttpHeaders.Names.CONTENT_LENGTH, "0");
                log.info("Sending redirect response!!");
                browserToProxyChannel.write(response);
                ProxyUtils.closeOnFlush(browserToProxyChannel);
                // Note this redirect should result in a new HTTPS request 
                // coming in on this connection or a new connection -- in fact
                // this redirect should always result in an HTTP CONNECT 
                // request as a result of the redirect. That new request
                // will not attempt to use the existing processor, so it's 
                // not an issue to return null here.
                return null;
            }
            log.info("Not converting to HTTPS");
            LanternHub.statsTracker().incrementProxiedRequests();
            return dispatchProxyRequest(ctx, me);
        } else {
            log.info("Not proxying!");
            LanternHub.statsTracker().incrementDirectRequests();
            try {
                this.unproxiedRequestProcessor.processRequest(
                    browserToProxyChannel, ctx, me);
            } catch (final IOException e) {
                // This should not happen because the underlying Netty handler
                // does not throw an exception.
                log.warn("Could not handle unproxied request -- " +
                    "should never happen", e);
            }
            return this.unproxiedRequestProcessor;
        }
    }
    
    private HttpRequestProcessor dispatchProxyRequest(
        final ChannelHandlerContext ctx, final MessageEvent me) {
        final HttpRequest request = (HttpRequest) me.getMessage();
        log.info("Dispatching request");
        if (request.getMethod() == HttpMethod.CONNECT) {
            try {
                if (ANONYMOUS_ACTIVE && 
                    LanternHub.getProxyProvider().getAnonymousPeerProxyManager().processRequest(
                        browserToProxyChannel, ctx, me) != null) {
                    log.info("Processed CONNECT on peer...returning");
                    return null;
                } else {
                    // We need to forward the CONNECT request from this proxy to an
                    // external proxy that can handle it. We effectively want to 
                    // relay all traffic in this case without doing anything on 
                    // our own other than direct the CONNECT request to the correct 
                    // proxy.
                    centralConnect(request);
                    return null;
                }
            } catch (final IOException e) {
                log.warn("Could not send CONNECT to anonymous proxy", e);
                // This will happen whenever the server's giving us bad
                // anonymous proxies, which could happen quite often.
                // We should fall back to central.
                centralConnect(request);
                return null;
            }

        }
        try {
            if (TRUSTED_ACTIVE) {
                final PeerProxyManager provider = 
                    LanternHub.getProxyProvider().getTrustedPeerProxyManager();
                if (provider != null) {
                    final HttpRequestProcessor rp = provider.processRequest(
                            browserToProxyChannel, ctx, me);
                    if (rp != null) {
                        return rp;
                    }
                }
            }
        } catch (final IOException e) {
            log.info("Caught exception processing request", e);
        }
        try {
            if (useLae() && isLae(request) && 
                this.laeRequestProcessor.processRequest(browserToProxyChannel, 
                    ctx, me)) {
                return this.laeRequestProcessor;
            } 
        } catch (final IOException e) {
            log.info("Caught exception processing request", e);
        }
        try {
            if (useStandardProxies() && 
                this.proxyRequestProcessor.processRequest(
                        browserToProxyChannel, ctx, me)) {
                log.info("Used standard proxy");
                return this.proxyRequestProcessor;
            }
        } catch (final IOException e) {
            log.info("Caught exception processing request", e);
        }
        
        log.warn("No proxy could process the request {}", me.getMessage());
        // Not much we can do if no proxy can handle it.
        return null;
    }

    private boolean useStandardProxies() {
        return PROXIES_ACTIVE && LanternHub.settings().isUseCloudProxies();
    }

    private boolean useLae() {
        return LAE_ACTIVE && LanternHub.settings().isUseCloudProxies();
    }

    private void centralConnect(final HttpRequest request) {
        if (this.httpConnectChannelFuture == null) {
            log.info("Opening HTTP CONNECT tunnel");
            try {
                this.httpConnectChannelFuture = 
                    openOutgoingRelayChannel(request);
            } catch (final IOException e) {
                log.error("Could not open CONNECT channel", e);
            }
        } else {
            log.error("Outbound channel already assigned?");
        }
    }

    private boolean isLae(final HttpRequest request) {
        final String uri = request.getUri();
        if (uri.contains("youtube.com")) {
            log.info("NOT USING LAE FOR YOUTUBE");
            return false;
        }
        final HttpMethod method = request.getMethod();
        if (method == HttpMethod.GET) {
            return true;
        }
        if (method == HttpMethod.CONNECT) {
            return false;
        }
        if (LanternUtils.isTransferEncodingChunked(request)) {
            return false;
        }
        if (method == HttpMethod.POST) {
            final String contentLength = 
                request.getHeader(Names.CONTENT_LENGTH);
            if (StringUtils.isBlank(contentLength)) {
                // If it's a post without a content length, we want to be 
                // cautious.
                return false;
            }
            final long cl = Long.parseLong(contentLength);
            if (cl > REQUEST_SIZE_LIMIT) {
                return false;
            }
            return true;
        }
        return false;
    }

    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) {
        log.info("Got incoming channel");
        this.browserToProxyChannel = e.getChannel();
    }
    
    private ChannelFuture openOutgoingRelayChannel(final HttpRequest request) 
        throws IOException {
        this.browserToProxyChannel.setReadable(false);

        // Start the connection attempt.
        final ClientBootstrap cb = 
            new ClientBootstrap(LanternUtils.clientSocketChannelFactory);
        
        final ChannelPipeline pipeline = cb.getPipeline();
        
        // This is slightly odd, as we tunnel SSL inside SSL, but we'd 
        // otherwise just be running an open CONNECT proxy.
        
        // It's also necessary to use our own engine here, as we need to trust
        // the cert from the proxy.
        final LanternClientSslContextFactory sslFactory =
            new LanternClientSslContextFactory(this.keyStoreManager);
        final SSLEngine engine =
            sslFactory.getClientContext().createSSLEngine();
        engine.setUseClientMode(true);
        
        ChannelHandler stats = new StatsTrackingHandler() {
            @Override
            public void addDownBytes(long bytes, Channel channel) {
                // global bytes proxied statistic
                //log.info("Recording proxied bytes through HTTP CONNECT: {}", bytes);
                statsTracker().addBytesProxied(bytes, channel);
                
                // contributes to local download rate
                statsTracker().addDownBytesViaProxies(bytes, channel);
            }

            @Override
            public void addUpBytes(long bytes, Channel channel) {
                statsTracker().addUpBytesViaProxies(bytes, channel);
            }
        };        

        pipeline.addLast("stats", stats);
        pipeline.addLast("ssl", new SslHandler(engine));
        pipeline.addLast("encoder", new HttpRequestEncoder());
        pipeline.addLast("handler", 
            new HttpConnectRelayingHandler(this.browserToProxyChannel, null));
        log.info("Connecting to relay proxy");
        final InetSocketAddress isa = LanternHub.getProxyProvider().getProxy();
        if (isa == null) {
            log.error("NO PROXY AVAILABLE?");
            ProxyUtils.closeOnFlush(browserToProxyChannel);
            throw new IOException("No proxy to use for CONNECT?");
        }
        final ChannelFuture cf = cb.connect(isa);
        log.info("Got an outbound channel on: {}", hashCode());
        
        final ChannelPipeline browserPipeline = 
            browserToProxyChannel.getPipeline();
        browserPipeline.remove("encoder");
        browserPipeline.remove("decoder");
        browserPipeline.remove("handler");
        browserPipeline.addLast("handler", 
            new HttpConnectRelayingHandler(cf.getChannel(), null));
        
        // This is handy, as set readable to false while the channel is 
        // connecting ensures we won't get any incoming messages until
        // we're fully connected.
        cf.addListener(new ChannelFutureListener() {
            @Override
            public void operationComplete(final ChannelFuture future) 
                throws Exception {
                if (future.isSuccess()) {
                    cf.getChannel().write(request).addListener(
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
                    LanternHub.getProxyStatusListener().onCouldNotConnect(isa);
                }
            }
        });
        
        return cf;
    }

    @Override 
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) {
        log.info("Got inbound channel closed. Closing outbound.");
        //this.trustedPeerRequestProcessor.close();
        //this.anonymousPeerRequestProcessor.close();
        if (this.currentRequestProcessor != null) {
            this.currentRequestProcessor.close();
        }
        this.proxyRequestProcessor.close();
        this.laeRequestProcessor.close();
    }
    
    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        log.error("Caught exception on INBOUND channel", e.getCause());
        ProxyUtils.closeOnFlush(this.browserToProxyChannel);
    }
    
}
