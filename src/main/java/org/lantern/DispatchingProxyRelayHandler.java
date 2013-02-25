package org.lantern;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.URI;

import javax.net.ssl.SSLContext;
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
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpChunk;
import org.jboss.netty.handler.codec.http.HttpHeaders.Names;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.ssl.SslHandler;
import org.lantern.httpseverywhere.HttpsEverywhere;
import org.lantern.state.Model;
import org.littleshoot.proxy.HttpConnectRelayingHandler;
import org.littleshoot.proxy.ProxyUtils;
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
    
    private final HttpRequestProcessor proxyRequestProcessor;
    
    private final HttpRequestProcessor laeRequestProcessor;
    
    private HttpRequestProcessor currentRequestProcessor;

    private boolean readingChunks;

    private final ClientSocketChannelFactory clientChannelFactory;

    private final ChannelGroup channelGroup;

    private final PeerProxyManager trustedPeerProxyManager;

    //private final PeerProxyManager anonymousPeerProxyManager;

    private final Stats stats;

    private final Model model;

    private final ProxyTracker proxyTracker;

    private final HttpsEverywhere httpsEverywhere;

    private final LanternTrustStore trustStore;

    /**
     * Creates a new handler that reads incoming HTTP requests and dispatches
     * them to proxies as appropriate.
     * 
     * @param clientChannelFactory The factory for creating outgoing channels
     * to external sites.
     * @param channelGroup Keeps track of channels to close on shutdown.
     */
    public DispatchingProxyRelayHandler(
        final ClientSocketChannelFactory clientChannelFactory,
        final ChannelGroup channelGroup,
        final PeerProxyManager trustedPeerProxyManager,
        //final PeerProxyManager anonymousPeerProxyManager,
        final Stats stats, final Model model, final ProxyTracker proxyTracker,
        final HttpsEverywhere httpsEverywhere,
        final LanternTrustStore trustStore) {
        this.clientChannelFactory = clientChannelFactory;
        this.channelGroup = channelGroup;
        this.trustedPeerProxyManager = trustedPeerProxyManager;
        //this.anonymousPeerProxyManager = anonymousPeerProxyManager;
        this.stats = stats;
        this.model = model;
        this.proxyTracker = proxyTracker;
        this.httpsEverywhere = httpsEverywhere;
        this.trustStore = trustStore;
        this.proxyRequestProcessor =
            new DefaultHttpRequestProcessor(proxyTracker,
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
                        return proxyTracker.getProxy();
                    }
                }, this.clientChannelFactory, this.channelGroup, this.stats, trustStore);
        this.laeRequestProcessor =
            new DefaultHttpRequestProcessor(proxyTracker,
                new LaeHttpRequestTransformer(), true,
                new Proxy() {
                    @Override
                    public URI getPeerProxy() {
                        throw new UnsupportedOperationException(
                            "Peer proxy not supported here.");
                    }
                    @Override
                    public InetSocketAddress getProxy() {
                        return proxyTracker.getLaeProxy();
                    }
            }, this.clientChannelFactory, this.channelGroup, this.stats, trustStore);
    }

    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        messagesReceived++;
        log.debug("Received {} total messages", messagesReceived);
        if (!readingChunks) {
            log.debug("Reading HTTP request (not a chunk)...");
            this.currentRequestProcessor = dispatchRequest(ctx, me);
        } 
        else {
            log.debug("Reading chunks...");
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
        log.debug("Done processing HTTP request....");
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
        
        // If it's an HTTP request, see if we can redirect it to HTTPS.
        /*
        final String https = httpsEverywhere.toHttps(uri);
        if (!https.equals(uri)) {
            final HttpResponse response = 
                new DefaultHttpResponse(request.getProtocolVersion(), 
                    HttpResponseStatus.MOVED_PERMANENTLY);
            response.setProtocolVersion(HttpVersion.HTTP_1_0);
            response.setHeader(HttpHeaders.Names.LOCATION, https);
            response.setHeader(HttpHeaders.Names.CONTENT_LENGTH, "0");
            log.info("Sending HTTPS redirect response!!");
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
        */
        log.debug("Not converting to HTTPS");
        this.stats.incrementProxiedRequests();
        return dispatchProxyRequest(ctx, me);
    }
    
    private HttpRequestProcessor dispatchProxyRequest(
        final ChannelHandlerContext ctx, final MessageEvent me) {
        final HttpRequest request = (HttpRequest) me.getMessage();
        log.debug("Dispatching request");
        if (request.getMethod() == HttpMethod.CONNECT) {
            try {
                if (this.model.getSettings().isUseAnonymousPeers() && 
                    trustedPeerProxyManager.processRequest(
                //if (LanternHub.settings().isUseTrustedPeers() && 
                //    LanternHub.getProxyProvider().getTrustedPeerProxyManager().processRequest(
                        browserToProxyChannel, ctx, me) != null) {
                    log.info("Processed CONNECT on peer...returning");
                    return null;
                } else if (useStandardProxies()){
                    // We need to forward the CONNECT request from this proxy 
                    // to an external proxy that can handle it. We effectively 
                    // want to relay all traffic in this case without doing 
                    // anything on our own other than direct the CONNECT 
                    // request to the correct proxy.
                    centralConnect(request);
                    return null;
                }
            } catch (final IOException e) {
                log.warn("Could not send CONNECT to anonymous proxy", e);
                // This will happen whenever the server's giving us bad
                // anonymous proxies, which could happen quite often.
                // We should fall back to central.
                if (useStandardProxies()) {
                    centralConnect(request);
                }
                return null;
            }

        }
        try {
            if (this.model.getSettings().isUseTrustedPeers()) {
                final PeerProxyManager provider = trustedPeerProxyManager;
                if (provider != null) {
                    log.info("Sending {} to trusted peers", request.getUri());
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
            log.info("Trying to send {} to LAE proxy", request.getUri());
            if (useLae() && isLae(request) && 
                this.laeRequestProcessor.processRequest(browserToProxyChannel, 
                    ctx, request)) {
                log.info("Sent {} to LAE proxy", request.getUri());
                return this.laeRequestProcessor;
            } 
        } catch (final IOException e) {
            log.info("Caught exception processing request", e);
        }
        try {
            log.info("Trying to send {} to standard proxy", request.getUri());
            if (useStandardProxies() && 
                this.proxyRequestProcessor.processRequest(
                        browserToProxyChannel, ctx, request)) {
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
        return this.model.getSettings().isUseCentralProxies() && model.getSettings().isUseCloudProxies();
    }

    private boolean useLae() {
        return this.model.getSettings().isUseLaeProxies() && model.getSettings().isUseCloudProxies();
    }

    private void centralConnect(final HttpRequest request) {
        if (this.httpConnectChannelFuture == null) {
            log.debug("Opening HTTP CONNECT tunnel");
            try {
                this.httpConnectChannelFuture = 
                    openHttpConnectChannelToCentralProxy(request);
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
        log.debug("Got incoming channel");
        this.browserToProxyChannel = e.getChannel();
        this.channelGroup.add(this.browserToProxyChannel);
    }
    
    private ChannelFuture openHttpConnectChannelToCentralProxy(
        final HttpRequest request) throws IOException {
        this.browserToProxyChannel.setReadable(false);

        // Start the connection attempt.
        final ClientBootstrap cb = 
            new ClientBootstrap(this.clientChannelFactory);
        
        final ChannelPipeline pipeline = cb.getPipeline();
        
        // This is slightly odd, as we tunnel SSL inside SSL, but we'd 
        // otherwise just be running an open CONNECT proxy.
        
        // It's also necessary to use our own engine here, as we need to trust
        // the cert from the proxy.
        final SSLEngine engine = trustStore.getContext().createSSLEngine();
        engine.setUseClientMode(true);
        
        final ChannelHandler statsHandler = new StatsTrackingHandler() {
            @Override
            public void addDownBytes(long bytes) {
                // contributes to local download rate
                stats.addDownBytesViaProxies(bytes);
            }

            @Override
            public void addUpBytes(long bytes) {
                stats.addUpBytesViaProxies(bytes);
            }
        };        

        pipeline.addLast("stats", statsHandler);
        pipeline.addLast("ssl", new SslHandler(engine));
        pipeline.addLast("encoder", new HttpRequestEncoder());
        pipeline.addLast("handler", 
            new HttpConnectRelayingHandler(this.browserToProxyChannel, 
                this.channelGroup));
        final InetSocketAddress isa = proxyTracker.getProxy();
        if (isa == null) {
            log.error("NO PROXY AVAILABLE?");
            ProxyUtils.closeOnFlush(browserToProxyChannel);
            throw new IOException("No proxy to use for CONNECT?");
        }
        log.debug("Connecting to relay proxy {} for {}", isa, request.getUri());
        final ChannelFuture cf = cb.connect(isa);
        log.debug("Got an outbound channel on: {}", hashCode());
        
        final ChannelPipeline browserPipeline = 
            browserToProxyChannel.getPipeline();
        remove(browserPipeline, "encoder");
        remove(browserPipeline, "decoder");
        remove(browserPipeline, "handler");
        remove(browserPipeline, "encoder");
        browserPipeline.addLast("handler", 
            new HttpConnectRelayingHandler(cf.getChannel(), 
                this.channelGroup));
        
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
                    proxyTracker.onCouldNotConnect(isa);
                }
            }
        });
        
        return cf;
    }

    private void remove(final ChannelPipeline cp, final String name) {
        final ChannelHandler ch = cp.get(name);
        if (ch != null) {
            cp.remove(name);
        }
    }

    @Override 
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) {
        log.debug("Got inbound channel closed. Closing outbound.");
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
        log.info("Caught exception on INBOUND channel", e.getCause());
        ProxyUtils.closeOnFlush(this.browserToProxyChannel);
    }
    
}