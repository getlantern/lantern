package org.lantern;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.nio.ByteBuffer;
import java.security.NoSuchAlgorithmException;
import java.util.Collection;
import java.util.Map;
import java.util.Queue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLEngine;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
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
import org.lastbamboo.common.offer.answer.NoAnswerException;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.proxy.HttpConnectRelayingHandler;
import org.littleshoot.util.ByteBufferUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handler that relays traffic to another proxy.
 */
public class DispatchingProxyRelayHandler extends SimpleChannelUpstreamHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Collection<String> whitelist;
    
    private volatile long messagesReceived = 0L;

    private ChannelFuture laeOutboundChannelFuture;
    
    private ChannelFuture proxyOutboundChannelFuture;
    
    /**
     * Outgoing channel that handles incoming HTTP Connect requests.
     */
    private ChannelFuture httpConnectChannelFuture;
    
    private Channel browserToProxyChannel;
    
    private static Map<URI, Long> peerConnectionTimes =
        new ConcurrentHashMap<URI, Long>();
    
    /**
     * Map recording the number of consecutive connection failures for a
     * given peer. Note that a successful connection will reset this count
     * back to zero.
     */
    private static Map<URI, AtomicInteger> peerFailureCount =
        new ConcurrentHashMap<URI, AtomicInteger>();

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

    private Socket outgoingPeerSocket;
    
    private Socket outgoingAnonymousSocket;

    private final XmppP2PClient p2pClient;

    private OutgoingWriter chunkWriter;

    /**
     * Creates a new handler that reads incoming HTTP requests and dispatches
     * them to proxies as appropriate.
     * 
     * @param proxyProvider Providers for proxy addresses to connect to.
     * @param proxyStatusListener The class to notify of changes in the proxy
     * status.
     * @param whitelist The list of sites to proxy.
     * @param p2pClient The client for creating P2P connections.
     */
    public DispatchingProxyRelayHandler(final ProxyProvider proxyProvider,
        final ProxyStatusListener proxyStatusListener, 
        final Collection<String> whitelist, final XmppP2PClient p2pClient) {
        this.proxyProvider = proxyProvider;
        this.proxyStatusListener = proxyStatusListener;
        this.whitelist = whitelist;
        this.p2pClient = p2pClient;
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
        try {
            this.chunkWriter.write(me);
        } catch (final IOException e) {
            // A peer proxy could have gone offline, the proxy could have
            // properly closed the connection due to connection closing rules,
            // etc.
            log.info("Got an exception", e);
        }
        //genericWrite(me.getMessage());
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
            if (this.httpConnectChannelFuture == null) {
                log.info("Opening HTTP CONNECT tunnel");
                this.httpConnectChannelFuture = 
                    openOutgoingRelayChannel(ctx, request);
            } else {
                log.error("Outbound channel already assigned?");
            }
        } else {
            if (isLae(request)) {
                if (this.laeOutboundChannelFuture == null) {
                    this.laeOutboundChannelFuture = 
                        openOutgoingChannel(this.proxyProvider.getLaeProxy(), 
                            true);
                }
                writeLaeRequest(uri, request, this.laeOutboundChannelFuture);
                this.chunkWriter = 
                    new ChannelChunkWriter(this.laeOutboundChannelFuture);
            } else {
                try {
                    final Socket sock = getPeerSocket(request, ctx);
                    writePeerRequest(request, sock, ctx.getChannel());
                    this.chunkWriter = new SocketChunkWriter(sock, request);
                } catch (final IOException e) {
                    // If we can't get a peer socket, we want to use a fallback
                    // centralized proxy.
                    if (this.proxyOutboundChannelFuture == null) {
                        this.proxyOutboundChannelFuture = 
                            openOutgoingChannel(this.proxyProvider.getProxy(), 
                                false);
                    }
                    writeRequest(request, this.proxyOutboundChannelFuture);
                    this.chunkWriter = 
                        new ChannelChunkWriter(this.proxyOutboundChannelFuture);
                }
            }
        }
    }
    
    private Socket getPeerSocket(final HttpRequest request, 
        final ChannelHandlerContext ctx) throws IOException {

        if (isAnonymous(request)) {
            if (this.outgoingAnonymousSocket == null) {
                try {
                    this.outgoingAnonymousSocket = 
                        openOutgoingPeerSocket(
                            this.proxyProvider.getLanternProxy(), ctx);
                    return this.outgoingAnonymousSocket;
                } catch (final IOException e) {
                    log.info("Could not open peer socket", e);
                }
            } else {
                return this.outgoingAnonymousSocket;
            }
        } 
        if (this.outgoingPeerSocket == null) {
            final URI peer = this.proxyProvider.getPeerProxy();
            try {
                this.outgoingPeerSocket = 
                    openOutgoingPeerSocket(peer, ctx);
            } catch (final IOException e) {
                log.info("Could not open peer socket", e);
            }
        } else {
            return this.outgoingPeerSocket;
        }
        // We could not open any peer socket. Peer sockets take a little 
        // longer to open, so we don't keep looping through them trying to
        // open more.
        throw new IOException("Could not connect to peer");
    }

    private void writePeerRequest(final HttpRequest request, final Socket sock,
        final Channel ch) {
        // We need to convert the Netty message to raw bytes for sending over
        // the socket.
        final RequestEncoder encoder = new RequestEncoder();
        final ChannelBuffer cb;
        try {
            cb = encoder.encode(request, ch);
        } catch (final Exception e) {
            log.error("Could not encode request?", e);
            return;
        }
        
        final ByteBuffer buf = cb.toByteBuffer();
        final byte[] data = ByteBufferUtils.toRawBytes(buf);
        try {
            log.info("Writing {}", new String(data));
            final OutputStream os = sock.getOutputStream();
            os.write(data);
        } catch (final IOException e) {
            // They probably just closed the connection, as they will in
            // many cases.
            //this.proxyStatusListener.onError(this.peerUri);
        }
    }
    
    /**
     * We subclass here purely to expose the encoding method of the built-in
     * request encoder.
     */
    private static final class RequestEncoder extends HttpRequestEncoder {
        private ChannelBuffer encode(final HttpRequest request, 
            final Channel ch) throws Exception {
            return (ChannelBuffer) super.encode(null, ch, request);
        }
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

    private void writeLaeRequest(final String uri, final HttpRequest request,
        final ChannelFuture cf) {
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
        writeRequest(request, cf);
    }

    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) {
        log.info("Got incoming channel");
        this.browserToProxyChannel = e.getChannel();
    }
    
    private ChannelFuture openOutgoingChannel(
        final InetSocketAddress proxyAddress, final boolean lae) {
        
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

        //this.laeOutboundChannelFuture = cf;
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
    
    private ChannelFuture openOutgoingRelayChannel(
        final ChannelHandlerContext ctx, final HttpRequest request) {
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

        //this.laeOutboundChannelFuture = cf;
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
    
    private Socket openOutgoingPeerSocket(
        final URI uri, final ChannelHandlerContext ctx) throws IOException {
        
        // This ensures we won't read any messages before we've successfully
        // created the socket.
        this.browserToProxyChannel.setReadable(false);

        // Start the connection attempt.
        try {
            log.info("Creating a new socket to {}", uri);
            final Socket sock = this.p2pClient.newSocket(uri);
            peerConnectionTimes.put(uri, System.currentTimeMillis());
            peerFailureCount.put(uri, new AtomicInteger(0));
            browserToProxyChannel.setReadable(true);
            startReading(sock, this.browserToProxyChannel);
            return sock;
        } catch (final NoAnswerException nae) {
            // This is tricky, as it can mean two things. First, it can mean
            // the XMPP message was somehow lost. Second, it can also mean
            // the other side is actually not there and didn't respond as a
            // result.
            log.info("Did not get answer!! Closing channel from browser", nae);
            final AtomicInteger count = peerFailureCount.get(uri);
            if (count == null) {
                log.info("Incrementing failure count");
                peerFailureCount.put(uri, new AtomicInteger(0));
            }
            else if (count.incrementAndGet() > 5) {
                log.info("Got a bunch of failures in a row to this peer. " +
                    "Removing it.");
                
                // We still reset it back to zero. Note this all should 
                // ideally never happen, and we should be able to use the
                // XMPP presence alerts to determine if peers are still valid
                // or not.
                peerFailureCount.put(uri, new AtomicInteger(0));
                proxyStatusListener.onCouldNotConnectToPeer(uri);
            } 
            throw nae;
        } catch (final IOException ioe) {
            proxyStatusListener.onCouldNotConnectToPeer(uri);
            log.warn("Could not connect to peer", ioe);
            throw ioe;
        }
    }
    
    private void startReading(final Socket sock, final Channel channel) {
        final Runnable runner = new Runnable() {

            public void run() {
                final byte[] buffer = new byte[4096];
                long count = 0;
                int n = 0;
                try {
                    final InputStream is = sock.getInputStream();
                    while (-1 != (n = is.read(buffer))) {
                        //log.info("Writing response data: {}", new String(buffer, 0, n));
                        // We need to make a copy of the buffer here because
                        // the writes are asynchronous, so the bytes can
                        // otherwise get scrambled.
                        final ChannelBuffer buf =
                            ChannelBuffers.copiedBuffer(buffer, 0, n);
                        channel.write(buf);
                        count += n;
                        log.info("In while");
                    }
                    log.info("Out of while");
                    LanternUtils.closeOnFlush(channel);

                } catch (final IOException e) {
                    log.info("Exception relaying peer data back to browser",e);
                    LanternUtils.closeOnFlush(channel);
                    
                    // The other side probably just closed the connection!!
                    
                    //channel.close();
                    //proxyStatusListener.onError(peerUri);
                    
                }
            }
        };
        final Thread peerReadingThread = 
            new Thread(runner, "Peer-Data-Reading-Thread");
        peerReadingThread.setDaemon(true);
        peerReadingThread.start();
    }

    @Override 
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) {
        log.info("Got inbound channel closed. Closing outbound.");
        if (this.laeOutboundChannelFuture != null) {
            LanternUtils.closeOnFlush(this.laeOutboundChannelFuture.getChannel());
        }
        if (this.proxyOutboundChannelFuture != null) {
            LanternUtils.closeOnFlush(this.proxyOutboundChannelFuture.getChannel());
        }
        if (this.httpConnectChannelFuture != null) {
            LanternUtils.closeOnFlush(this.httpConnectChannelFuture.getChannel());
        }
        if (this.outgoingAnonymousSocket != null) {
            IOUtils.closeQuietly(outgoingAnonymousSocket);
        }
        if (this.outgoingPeerSocket != null) {
            IOUtils.closeQuietly(outgoingPeerSocket);
        }
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
                    requestRange(request, response, cr, cl, ctx.getChannel());
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
    private void writeRequest(final HttpRequest request, 
        final ChannelFuture cf) {
        this.httpRequests.add(request);
        log.info("Writing request: {}", request);
        genericWrite(request, cf);
    }
    
    /**
     * Helper method that ensures all written requests are properly recorded.
     * 
     * @param request The request.
     */
    private void writeRequest(final HttpRequest request, final Channel channel) {
        this.httpRequests.add(request);
        log.info("Writing request: {}", request);
        channel.write(request);
    }
    
    private void genericWrite(final Object message, 
        final ChannelFuture future) {
        final Channel ch = future.getChannel();
        if (ch.isConnected()) {
            ch.write(message);
        } else {
            future.addListener(new ChannelFutureListener() {
                
                public void operationComplete(final ChannelFuture cf) 
                    throws Exception {
                    if (cf.isSuccess()) {
                        ch.write(message);
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
        final long fullContentLength, final Channel channel) {
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
        writeRequest(request, channel);
    }
}
