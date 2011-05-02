package org.lantern;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.URI;
import java.util.Collection;

import javax.net.ssl.SSLEngine;

import org.apache.commons.lang.StringUtils;
import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.handler.codec.http.HttpChunk;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpHeaders.Names;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.ssl.SslHandler;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.proxy.HttpConnectRelayingHandler;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.proxy.SslContextFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handler that relays traffic to another proxy, dispatching between 
 * appropriate proxies depending on the type of request.
 */
public class DispatchingProxyRelayHandler extends SimpleChannelUpstreamHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Collection<String> whitelist;
    
    private volatile long messagesReceived = 0L;

    /**
     * Outgoing channel that handles incoming HTTP Connect requests.
     */
    private ChannelFuture httpConnectChannelFuture;
    
    private Channel browserToProxyChannel;

    private final ProxyStatusListener proxyStatusListener;
    
    private final ProxyProvider proxyProvider;

    private static final long REQUEST_SIZE_LIMIT = 1024 * 1024 * 10 - 4096;

    private static final boolean PROXIES_ACTIVE = true;

    private static final boolean ANONYMOUS_ACTIVE = true;

    private static final boolean TRUSTED_ACTIVE = true;

    private static final boolean LAE_ACTIVE = true;
    
    private final HttpRequestProcessor unproxiedRequestProcessor = 
        new HttpRequestProcessor() {
            private final HttpRequestHandler requestHandler = 
                new HttpRequestHandler();
            public void processRequest(final Channel browserChannel,
                final ChannelHandlerContext ctx, final MessageEvent me) 
                throws IOException {
                requestHandler.messageReceived(ctx, me);
            }
            
            public boolean hasProxy() {
                return false;
            }

            public void processChunk(final ChannelHandlerContext ctx, 
                final MessageEvent me) throws IOException {
                requestHandler.messageReceived(ctx, me);
            }
            public void close() {
            }
        };
    
    
    private final HttpRequestProcessor proxyRequestProcessor;
    
    private final HttpRequestProcessor anonymousPeerRequestProcessor;
    
    private final HttpRequestProcessor trustedPeerRequestProcessor;
    
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
     * @param proxyProvider Providers for proxy addresses to connect to.
     * @param proxyStatusListener The class to notify of changes in the proxy
     * status.
     * @param whitelist The list of sites to proxy.
     * @param p2pClient The client for creating P2P connections.
     * @param keyStoreManager Keeps track of all trusted keys. 
     */
    public DispatchingProxyRelayHandler(final ProxyProvider proxyProvider,
        final ProxyStatusListener proxyStatusListener, 
        final Collection<String> whitelist, final XmppP2PClient p2pClient, 
        final KeyStoreManager keyStoreManager) {
        this.proxyProvider = proxyProvider;
        this.proxyStatusListener = proxyStatusListener;
        this.whitelist = whitelist;
        this.keyStoreManager = keyStoreManager;
        this.anonymousPeerRequestProcessor =
            new PeerHttpRequestProcessor(new Proxy() {
                public InetSocketAddress getProxy() {
                    throw new UnsupportedOperationException(
                        "Peer proxy required");
                }
                public URI getPeerProxy() {
                    return proxyProvider.getLanternProxy();
                }
            },  proxyStatusListener, p2pClient);
        
        this.trustedPeerRequestProcessor =
            new PeerHttpRequestProcessor(new Proxy() {
                public InetSocketAddress getProxy() {
                    throw new UnsupportedOperationException(
                        "Peer proxy required");
                }
                public URI getPeerProxy() {
                    return proxyProvider.getPeerProxy();
                }
            },  proxyStatusListener, p2pClient);
        
        this.proxyRequestProcessor =
            new DefaultHttpRequestProcessor(proxyStatusListener,
                new HttpRequestTransformer() {
                    public void transform(final HttpRequest request, 
                        final InetSocketAddress proxyAddress) {
                        // Does nothing.
                    }
                }, false,
                new Proxy() {
                    public URI getPeerProxy() {
                        throw new UnsupportedOperationException(
                            "Peer proxy not supported here.");
                    }
                    public InetSocketAddress getProxy() {
                        return proxyProvider.getProxy();
                    }
                }, this.keyStoreManager);
        this.laeRequestProcessor =
            new DefaultHttpRequestProcessor(proxyStatusListener,
                new LaeHttpRequestTransformer(), true,
                new Proxy() {
                    public URI getPeerProxy() {
                        throw new UnsupportedOperationException(
                            "Peer proxy not supported here.");
                    }
                    public InetSocketAddress getProxy() {
                        return proxyProvider.getLaeProxy();
                    }
            }, this.keyStoreManager);
    }

    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        messagesReceived++;
        log.info("Received {} total messages", messagesReceived);
        if (!readingChunks) {
            this.currentRequestProcessor = dispatchRequest(ctx, me);
        } 
        else {
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
    }
    
    private HttpRequestProcessor dispatchRequest(
        final ChannelHandlerContext ctx, final MessageEvent me) {
        final HttpRequest request = (HttpRequest)me.getMessage();
        final String uri = request.getUri();
        log.info("URI is: {}", uri);

        final String referer = request.getHeader("referer");
        
        final String uriToCheck;
        log.info("Referer: "+referer);
        if (!StringUtils.isBlank(referer)) {
            uriToCheck = referer;
        } else {
            uriToCheck = uri;
        }
        
        this.proxying = 
            DomainWhitelister.isWhitelisted(uriToCheck, whitelist);
        
        if (proxying) {
            if (request.isChunked()) {
                readingChunks = true;
            } else {
                readingChunks = false;
            }
            return dispatchProxyRequest(ctx, me);
        } else {
            log.info("Not proxying!");
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
        if (request.getMethod() == HttpMethod.CONNECT) {
            // We need to forward the CONNECT request from this proxy to an
            // external proxy that can handle it. We effectively want to 
            // relay all traffic in this case without doing anything on 
            // our own other than direct the CONNECT request to the correct 
            // proxy.
            if (this.httpConnectChannelFuture == null) {
                log.info("Opening HTTP CONNECT tunnel");
                this.httpConnectChannelFuture = 
                    openOutgoingRelayChannel(ctx, request);
                return null;
            } else {
                log.error("Outbound channel already assigned?");
            }
        }
        
        if (LAE_ACTIVE && isLae(request) && this.laeRequestProcessor.hasProxy()) {
            try {
                this.laeRequestProcessor.processRequest(browserToProxyChannel, 
                    ctx, me);
                return this.laeRequestProcessor;
            } catch (final IOException e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
            }
        } 
        if (TRUSTED_ACTIVE && this.trustedPeerRequestProcessor.hasProxy())  {
            try {
                this.trustedPeerRequestProcessor.processRequest(
                    browserToProxyChannel, ctx, me);
                return this.trustedPeerRequestProcessor;
            } catch (final IOException e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
            }
        } 
        if (ANONYMOUS_ACTIVE && isAnonymous(request) && 
            this.anonymousPeerRequestProcessor.hasProxy()) {
            try {
                this.anonymousPeerRequestProcessor.processRequest(
                    browserToProxyChannel, ctx, me);
                return this.anonymousPeerRequestProcessor;
            } catch (IOException e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
            }
            
        } 
        if (PROXIES_ACTIVE && this.proxyRequestProcessor.hasProxy()) {
            log.info("Using standard proxy");
            try {
                this.proxyRequestProcessor.processRequest(
                    browserToProxyChannel, ctx, me);
                return this.proxyRequestProcessor;
            } catch (IOException e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
            }
        }
        
        // Not much we can do if no proxy can handle it.
        return null;
    }

    private boolean isAnonymous(final HttpRequest request) {
        final String cookie = request.getHeader(HttpHeaders.Names.COOKIE);
        if (StringUtils.isNotBlank(cookie)) {
            return false;
        }
        final HttpMethod method = request.getMethod();
        if (method == HttpMethod.CONNECT) {
            return false;
        }
        if (method == HttpMethod.POST) {
            return false;
        }
        if (method == HttpMethod.PUT) {
            return false;
        }
        return true;
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
        // From http://code.google.com/appengine/docs/quotas.html, we cannot
        // send requests larger than 10MB. 
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
    
    private ChannelFuture openOutgoingRelayChannel(
        final ChannelHandlerContext ctx, final HttpRequest request) {
        this.browserToProxyChannel.setReadable(false);

        // Start the connection attempt.
        final ClientBootstrap cb = 
            new ClientBootstrap(LanternUtils.clientSocketChannelFactory);
        
        final ChannelPipeline pipeline = cb.getPipeline();
        
        // This is slightly odd, as we tunnel SSL inside SSL, but we'd 
        // otherwise just be running an open CONNECT proxy.
        final SslContextFactory sslFactory =
            new SslContextFactory(this.keyStoreManager);
        final SSLEngine engine =
            sslFactory.getClientContext().createSSLEngine();
        engine.setUseClientMode(true);
        pipeline.addLast("ssl", new SslHandler(engine));
        pipeline.addLast("encoder", new HttpRequestEncoder());
        pipeline.addLast("handler", 
            new HttpConnectRelayingHandler(this.browserToProxyChannel, null));
        
        log.info("Connecting to relay proxy");
        final InetSocketAddress isa = this.proxyProvider.getProxy();
        final ChannelFuture cf = cb.connect(isa);

        log.info("Got an outbound channel on: {}", hashCode());
        final ChannelPipeline browserPipeline = ctx.getPipeline();
        browserPipeline.remove("encoder");
        browserPipeline.remove("decoder");
        browserPipeline.remove("handler");
        browserPipeline.addLast("handler", 
            new HttpConnectRelayingHandler(cf.getChannel(), null));
        
        // This is handy, as set readable to false while the channel is 
        // connecting ensures we won't get any incoming messages until
        // we're fully connected.
        cf.addListener(new ChannelFutureListener() {
            public void operationComplete(final ChannelFuture future) 
                throws Exception {
                if (future.isSuccess()) {
                    cf.getChannel().write(request).addListener(
                        new ChannelFutureListener() {
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
                    proxyStatusListener.onCouldNotConnect(isa);
                }
            }
        });
        
        return cf;
    }

    @Override 
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) {
        log.info("Got inbound channel closed. Closing outbound.");
        this.trustedPeerRequestProcessor.close();
        this.anonymousPeerRequestProcessor.close();
        this.proxyRequestProcessor.close();
        this.laeRequestProcessor.close();
    }
    
    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        log.error("Caught exception on INBOUND channel", e.getCause());
        LanternUtils.closeOnFlush(this.browserToProxyChannel);
    }
    
}
