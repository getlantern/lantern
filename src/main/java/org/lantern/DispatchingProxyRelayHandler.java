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
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.codec.http.HttpResponse;
import org.jboss.netty.handler.codec.http.HttpResponseDecoder;
import org.jboss.netty.handler.codec.http.HttpResponseStatus;
import org.jboss.netty.handler.ssl.SslHandler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handler that relays traffic to another proxy.
 */
public class DispatchingProxyRelayHandler extends SimpleChannelUpstreamHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Collection<String> whitelist;
    
    private volatile long messagesReceived = 0L;

    private final InetSocketAddress proxyAddress;

    private Channel outboundChannel;

    private Channel inboundChannel;

    private final ProxyStatusListener proxyStatusListener;
    
    private final ClientSocketChannelFactory clientSocketChannelFactory =
        new NioClientSocketChannelFactory(
            Executors.newCachedThreadPool(),
            Executors.newCachedThreadPool());

    private final Queue<HttpRequest> httpRequests = 
        new ConcurrentLinkedQueue<HttpRequest>();
    
    /**
     * Creates a new handler that reads incoming HTTP requests and dispatches
     * them to proxies as appropriate.
     * 
     * @param proxyAddress The address of the proxy.
     * @param proxyStatusListener The class to notify of changes in the proxy
     * status.
     * @param whitelist The list of sites not to proxy.
     */
    public DispatchingProxyRelayHandler(final InetSocketAddress proxyAddress, 
        final ProxyStatusListener proxyStatusListener, 
        final Collection<String> whitelist) {
        this.proxyAddress = proxyAddress;
        this.proxyStatusListener = proxyStatusListener;
        this.whitelist = whitelist;
    }

    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent me) {

        messagesReceived++;
        log.info("Received {} total messages", messagesReceived);
        final Object msg = me.getMessage();
        log.info("Msg is "+msg);
        
        // TODO: This could be a chunk!! We also need to reset this somehow
        // when the current request changes. Tricky.
        final HttpRequest request = (HttpRequest)msg;
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
        
        final boolean shouldProxy = 
            DomainWhitelister.isWhitelisted(uriToCheck, whitelist);
        
        if (shouldProxy) {
            log.info("Proxying!");
            // We need to decide which proxy to send the request to here.
            final String proxyHost = "laeproxy.appspot.com";
            //final String proxyHost = "127.0.0.1";
            final String proxyBaseUri = "https://" + proxyHost;
            if (!uri.startsWith(proxyBaseUri)) {
                request.setHeader("Host", proxyHost);
                final String scheme = uri.substring(0, uri.indexOf(':'));
                final String rest = uri.substring(scheme.length() + 3);
                final String proxyUri = proxyBaseUri + "/" + scheme + "/" + rest;
                log.debug("proxyUri: " + proxyUri);
                request.setUri(proxyUri);
            } else {
                log.info("NOT MODIFYING URI -- ALREADY HAS FREELANTERN");
            }
            writeRequest(request);
        } else {
            log.info("Not proxying!");
            final HttpRequestHandler rh = new HttpRequestHandler();
            rh.messageReceived(ctx, me);
        }
    }

    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) {
        final Channel channel = e.getChannel();
        if (this.outboundChannel != null) {
            log.error("Outbound channel already assigned?");
        }
        this.inboundChannel = channel;
        inboundChannel.setReadable(false);

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
        pipeline.addLast("handler", 
            new OutboundHandler(this.inboundChannel));
        final ChannelFuture cf = cb.connect(this.proxyAddress);

        this.outboundChannel = cf.getChannel();
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
                    inboundChannel.setReadable(true);
                } else {
                    // Close the connection if the connection attempt has failed.
                    inboundChannel.close();
                    proxyStatusListener.onCouldNotConnect(proxyAddress);
                }
            }
        });
    }

    @Override 
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) {
        log.info("Got inbound channel closed. Closing outbound.");
        LanternUtils.closeOnFlush(this.outboundChannel);
    }
    
    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        log.error("Caught exception on INBOUND channel", e.getCause());
        LanternUtils.closeOnFlush(this.inboundChannel);
    }
    
    private class OutboundHandler extends SimpleChannelUpstreamHandler {

        private final Logger log = LoggerFactory.getLogger(getClass());
        
        private final Channel inboundChannel;

        OutboundHandler(final Channel inboundChannel) {
            this.inboundChannel = inboundChannel;
        }

        @Override
        public void messageReceived(final ChannelHandlerContext ctx, 
            final MessageEvent e) {
            final Object msg = e.getMessage();
            
            if (msg instanceof HttpChunk) {
                final HttpChunk chunk = (HttpChunk) msg;
                
                if (chunk.isLast()) {
                    log.info("GOT LAST CHUNK");
                }
                inboundChannel.write(chunk);
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
                    inboundChannel.write(response);
                } else {
                    
                    
                    // We just grab this before the thread because we're about
                    // to remove it.
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
                        inboundChannel.write(response);
                    } else {
                        // We need to grab the body of the partial response
                        // and return it as an HTTP chunk.
                        final HttpChunk chunk = 
                            new DefaultHttpChunk(response.getContent());
                        inboundChannel.write(chunk);
                    }
                    
                    // Spin up additional requests on a new thread.
                    queueRangeRequests(request, response, cr, cl);
                }
            }
        }

        @Override
        public void channelClosed(final ChannelHandlerContext ctx, 
            final ChannelStateEvent e) throws Exception {
            LanternUtils.closeOnFlush(inboundChannel);
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
        this.outboundChannel.write(request);
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

    private void queueRangeRequests(final HttpRequest request, 
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
        final long end;
        if (contentLength - start > CHUNK_SIZE) {
            end = start + CHUNK_SIZE;
        } else {
            end = fullContentLength;
        }
        request.setHeader(HttpHeaders.Names.RANGE, "bytes="+start+"-"+end);
        writeRequest(request);
    }

}
