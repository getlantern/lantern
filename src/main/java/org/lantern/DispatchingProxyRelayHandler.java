package org.lantern;

import java.net.InetSocketAddress;
import java.security.NoSuchAlgorithmException;
import java.util.Collection;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.Executors;

import javax.net.ssl.SSLContext;
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
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.handler.codec.http.DefaultHttpChunk;
import org.jboss.netty.handler.codec.http.HttpChunk;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpHeaders.Names;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.codec.http.HttpResponse;
import org.jboss.netty.handler.codec.http.HttpResponseDecoder;
import org.jboss.netty.handler.codec.http.HttpResponseStatus;
import org.jboss.netty.handler.ssl.SslHandler;
import org.littleshoot.proxy.HttpConnectRelayingHandler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handler that relays traffic to another proxy.
 */
public class DispatchingProxyRelayHandler extends SimpleChannelUpstreamHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Collection<String> whitelist;
    
    private volatile long messagesReceived = 0L;

    private ChannelFuture outboundChannelFuture;

    private Channel browserToProxyChannel;

    private final ProxyStatusListener proxyStatusListener;
    
    private final ClientSocketChannelFactory clientSocketChannelFactory =
        new NioClientSocketChannelFactory(
            Executors.newCachedThreadPool(),
            Executors.newCachedThreadPool());

    private final Queue<HttpRequest> httpRequests = 
        new ConcurrentLinkedQueue<HttpRequest>();

    private final ProxyProvider proxyProvider;

    private String proxyHost;
    
    private static final long REQUEST_SIZE_LIMIT = 1024 * 1024 * 10 - 4096;
    
    private final HttpRequestHandler requestHandler = new HttpRequestHandler();

    private boolean readingChunks;

    /**
     * Specifies whether or not we're currently proxying requests. This is 
     * necessary because we don't have all the initial HTTP request data,
     * such as the referer or the URI, when we're processing HTTP chunks.
     */
    private boolean proxying;

    private boolean isLae;
    
    /**
     * Creates a new handler that reads incoming HTTP requests and dispatches
     * them to proxies as appropriate.
     * 
     * @param proxyStatusListener The class to notify of changes in the proxy
     * status.
     * @param whitelist The list of sites to proxy.
     */
    public DispatchingProxyRelayHandler(final ProxyProvider proxyProvider,
        final ProxyStatusListener proxyStatusListener, 
        final Collection<String> whitelist) {
        this.proxyProvider = proxyProvider;
        this.proxyStatusListener = proxyStatusListener;
        this.whitelist = whitelist;
    }

    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        messagesReceived++;
        log.info("Received {} total messages", messagesReceived);
        if (!readingChunks) {
            processRequest(ctx, me);
        } 
        else {
            processChunk(ctx, me);
        }
    }
    
    private void processChunk(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        log.info("Processing chunk...");
        final HttpChunk chunk = (HttpChunk) me.getMessage();
        
        // Remember this will typically be a persistent connection, so we'll
        // get another request after we're read the last chunk. So we need to
        // reset it back to no longer read in chunk mode.
        if (chunk.isLast()) {
            this.readingChunks = false;
        }
        if (this.proxying) {
            // We need to make sure we send this to a proxy that's capable 
            // of handling HTTP chunks.
            processChunkWithProxy(ctx, me);
        } else {
            this.requestHandler.messageReceived(ctx, me);
        }
    }
    
    private void processChunkWithProxy(final ChannelHandlerContext ctx,
        final MessageEvent me) {
        genericWrite(me.getMessage());
    }

    private void processRequest(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
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
            processRequestWithProxy(uri, ctx, request);
        } else {
            log.info("Not proxying!");
            this.requestHandler.messageReceived(ctx, me);
        }
        if (request.isChunked()) {
            readingChunks = true;
        } else {
            readingChunks = false;
        }
    }

    private void processRequestWithProxy(final String uri, 
        final ChannelHandlerContext ctx, final HttpRequest request) {
        log.info("Proxying!");
        if (request.getMethod() == HttpMethod.CONNECT) {
            // We need to forward the CONNECT request from this proxy to an
            // external proxy that can handle it. We effectively want to 
            // relay all traffic in this case without doing anything on 
            // our own other than direct the CONNECT request to the correct 
            // proxy.
            if (this.outboundChannelFuture == null) {
                log.info("Opening HTTP CONNECT tunnel");
                openOutgoingRelayChannel(ctx, request);
            } else {
                log.error("Outbound channel already assigned?");
            }
        } else {
            this.isLae = isLae(request);
            if (this.outboundChannelFuture == null) {
                log.error("Outbound channel already assigned?");
                final ChannelFuture future;
                if (isLae) {
                    future = openLaeOutgoingChannel();
                } else {
                    future = openStandardOutgoingChannel();
                }
                future.addListener(new ChannelFutureListener() {
                    
                    public void operationComplete(final ChannelFuture cf) 
                        throws Exception {
                        if (cf.isSuccess()) {
                            writeRequest(uri, request);
                        }
                    }
                });
            } else {
                // It's possible we could be receiving a new request type
                // the requires a different type of proxy than the prior one,
                // so we need to do extra processing to determine that.
                writeRequest(uri, request);
            }
        }
    }
    
    private boolean isLae(final HttpRequest request) {
        final HttpMethod method = request.getMethod();
        if (method == HttpMethod.GET) {
            return true;
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

    private void writeRequest(final String uri, final HttpRequest request) {
        // We need to decide which proxy to send the request to here.
        //final String proxyHost = "laeproxy.appspot.com";
        //final String proxyHost = "127.0.0.1";
        final String proxyBaseUri = "https://" + this.proxyHost;
        if (!uri.startsWith(proxyBaseUri)) {
            request.setHeader("Host", this.proxyHost);
            final String scheme = uri.substring(0, uri.indexOf(':'));
            final String rest = uri.substring(scheme.length() + 3);
            final String proxyUri = proxyBaseUri + "/" + scheme + "/" + rest;
            log.debug("proxyUri: " + proxyUri);
            request.setUri(proxyUri);
        } else {
            log.info("NOT MODIFYING URI -- ALREADY HAS FREELANTERN");
        }
        writeRequest(request);
    }

    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) {
        log.info("Got incoming channel");
        this.browserToProxyChannel = e.getChannel();
    }
    
    private ChannelFuture openLaeOutgoingChannel() {
        return openOutgoingChannel(this.proxyProvider.getLaeProxy(), true);
    }
    
    private ChannelFuture openStandardOutgoingChannel() {
        return openOutgoingChannel(this.proxyProvider.getProxy(), false);
    }
    
    private ChannelFuture openOutgoingChannel(
        final InetSocketAddress proxyAddress, final boolean lae) {
        
        if (this.outboundChannelFuture != null) {
            log.error("Outbound channel already assigned?");
        }
        browserToProxyChannel.setReadable(false);

        // Start the connection attempt.
        final ClientBootstrap cb = 
            new ClientBootstrap(this.clientSocketChannelFactory);
        
        final ChannelPipeline pipeline = cb.getPipeline();
        try {
            log.info("Creating SSL engine");
            final SSLEngine engine =
                SSLContext.getDefault().createSSLEngine();
            engine.setUseClientMode(true);
            pipeline.addLast("ssl", new SslHandler(engine));
        } catch (final NoSuchAlgorithmException nsae) {
            log.error("Could not create default SSL context");
        }
        
        pipeline.addLast("decoder", new HttpResponseDecoder());
        pipeline.addLast("encoder", new HttpRequestEncoder());
        pipeline.addLast("handler", new OutboundHandler());
        this.proxyHost = proxyAddress.getHostName();
        
        log.info("Connecting to proxy at: {}", proxyAddress);
        
        final ChannelFuture cf = cb.connect(proxyAddress);

        this.outboundChannelFuture = cf;
        //this.outboundChannel = cf.getChannel();
        log.info("Got an outbound channel on: {}", hashCode());
        
        // This is handy, as set readable to false while the channel is 
        // connecting ensures we won't get any incoming messages until
        // we're fully connected.
        cf.addListener(new ChannelFutureListener() {
            public void operationComplete(final ChannelFuture future) 
                throws Exception {
                if (future.isSuccess()) {
                    // Connection attempt succeeded:
                    // Begin to accept incoming traffic.
                    browserToProxyChannel.setReadable(true);
                } else {
                    // Close the connection if the connection attempt has failed.
                    browserToProxyChannel.close();
                    if (lae) {
                        proxyStatusListener.onCouldNotConnectToLae(proxyAddress);
                    } else {
                        proxyStatusListener.onCouldNotConnect(proxyAddress);
                    }
                }
            }
        });
        return cf;
    }
    
    private void openOutgoingRelayChannel(final ChannelHandlerContext ctx, 
        final HttpRequest request) {
        
        if (this.outboundChannelFuture != null) {
            log.error("Outbound channel already assigned?");
        }
        //this.browserToProxyChannel = incomingChannel;
        browserToProxyChannel.setReadable(false);

        // Start the connection attempt.
        final ClientBootstrap cb = 
            new ClientBootstrap(this.clientSocketChannelFactory);
        
        final ChannelPipeline pipeline = cb.getPipeline();
        pipeline.addLast("encoder", new HttpRequestEncoder());
        pipeline.addLast("handler", 
            new HttpConnectRelayingHandler(browserToProxyChannel, null));
        
        log.info("Connecting to relay proxy");
        final InetSocketAddress isa = this.proxyProvider.getProxy();
        final ChannelFuture cf = cb.connect(isa);

        this.outboundChannelFuture = cf;
        //this.outboundChannel = cf.getChannel();
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
                                final ChannelFuture future) throws Exception {
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
    }

    @Override 
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) {
        log.info("Got inbound channel closed. Closing outbound.");
        LanternUtils.closeOnFlush(this.outboundChannelFuture.getChannel());
    }
    
    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        log.error("Caught exception on INBOUND channel", e.getCause());
        LanternUtils.closeOnFlush(this.browserToProxyChannel);
    }
    
    private class OutboundHandler extends SimpleChannelUpstreamHandler {

        @Override
        public void messageReceived(final ChannelHandlerContext ctx, 
            final MessageEvent e) {
            final Object msg = e.getMessage();
            
            if (msg instanceof HttpChunk) {
                final HttpChunk chunk = (HttpChunk) msg;
                
                if (chunk.isLast()) {
                    log.info("GOT LAST CHUNK");
                }
                browserToProxyChannel.write(chunk);
            } else {
                log.info("Got message on outbound handler: {}", msg);
                // There should always be a one-to-one relaationship between
                // requests and responses, so we want to pop a request off the
                // queue for every response we get in. This is only really
                // needed so we have all the appropriate request values for
                // making additional requests to handle 206 partial responses.
                final HttpRequest request = httpRequests.remove();
                //final ChannelBuffer msg = (ChannelBuffer) e.getMessage();
                //if (msg instanceof HttpResponse) {
                final HttpResponse response = (HttpResponse) msg;
                final int code = response.getStatus().getCode();
                if (code != 206) {
                    log.info("No 206. Writing whole response");
                    browserToProxyChannel.write(response);
                } else {
                    
                    
                    // We just grab this before queuing the request because
                    // we're about to remove it.
                    final String cr = 
                        response.getHeader(HttpHeaders.Names.CONTENT_RANGE);
                    final long cl = parseFullContentLength(cr);
                    
                    if (isFirstChunk(cr)) {
                        // If this is the *first* partial response to this 
                        // request, we need to build a new HTTP response as if 
                        // it were a normal, non-partial 200 OK. We need to 
                        // make sure not to do this for *every* 206 response, 
                        // however.
                        response.setStatus(HttpResponseStatus.OK);
                        
                        log.info("Setting Content Length to: "+cl+" from "+cr);
                        response.setHeader(HttpHeaders.Names.CONTENT_LENGTH, cl);
                        response.removeHeader(HttpHeaders.Names.CONTENT_RANGE);
                        browserToProxyChannel.write(response);
                    } else {
                        // We need to grab the body of the partial response
                        // and return it as an HTTP chunk.
                        final HttpChunk chunk = 
                            new DefaultHttpChunk(response.getContent());
                        browserToProxyChannel.write(chunk);
                    }
                    
                    // Spin up additional requests on a new thread.
                    requestRange(request, response, cr, cl);
                }
            }
        }

        @Override
        public void channelClosed(final ChannelHandlerContext ctx, 
            final ChannelStateEvent e) throws Exception {
            LanternUtils.closeOnFlush(browserToProxyChannel);
        }

        @Override
        public void exceptionCaught(final ChannelHandlerContext ctx, 
            final ExceptionEvent e) throws Exception {
            log.error("Caught exception on OUTBOUND channel", e.getCause());
            LanternUtils.closeOnFlush(e.getChannel());
        }
    }
    

    /**
     * Helper method that ensures all written requests are properly recorded.
     * 
     * @param request The request.
     */
    private void writeRequest(final HttpRequest request) {
        this.httpRequests.add(request);
        log.info("Writing request: {}", request);
        genericWrite(request);
    }
    
    private void genericWrite(final Object message) {
        final Channel ch = this.outboundChannelFuture.getChannel();
        if (ch.isConnected()) {
            ch.write(message);
        } else {
            this.outboundChannelFuture.addListener(new ChannelFutureListener() {
                
                public void operationComplete(final ChannelFuture cf) 
                    throws Exception {
                    if (cf.isSuccess()) {
                        cf.getChannel().write(message);
                    }
                }
            });
        }
    }
    
    private boolean isFirstChunk(final String contentRange) {
        return contentRange.trim().startsWith("bytes 0-");
    }

    private long parseFullContentLength(final String contentRange) {
        final String fullLength = 
            StringUtils.substringAfterLast(contentRange, "/");
        return Long.parseLong(fullLength);
    }

    private static final long CHUNK_SIZE = 1024 * 1024 * 10 - (2 * 1024);

    private void requestRange(final HttpRequest request, 
        final HttpResponse response, final String contentRange, 
        final long fullContentLength) {
        log.info("Queuing request based on Content-Range: {}", contentRange);
        // Note we don't need to thread this since it's all asynchronous 
        // anyway.
        final String body = 
            StringUtils.substringAfter(contentRange, "bytes ");
        if (StringUtils.isBlank(body)) {
            log.error("Blank bytes body: "+contentRange);
            return;
        }
        final long contentLength = HttpHeaders.getContentLength(response);
        final String startPlus = StringUtils.substringAfter(body, "-");
        final String startString = StringUtils.substringBefore(startPlus, "/");
        final long start = Long.parseLong(startString) + 1;
        
        // This means the last response provided the final range, so we don't
        // want to request another one.
        if (start == fullContentLength) {
            log.info("Received full length...not requesting new range");
            return;
        }
        final long end;
        if (contentLength - start > CHUNK_SIZE) {
            end = start + CHUNK_SIZE;
        } else {
            end = fullContentLength - 1;
        }
        request.setHeader(HttpHeaders.Names.RANGE, "bytes="+start+"-"+end);
        writeRequest(request);
    }
}
