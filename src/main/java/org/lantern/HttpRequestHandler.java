package org.lantern;

import static org.jboss.netty.channel.Channels.pipeline;

import java.net.InetSocketAddress;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;

import org.apache.commons.lang.StringUtils;
import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpChunk;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.codec.http.HttpResponseDecoder;
import org.littleshoot.proxy.HttpConnectRelayingHandler;
import org.littleshoot.proxy.HttpRelayingHandler;
import org.littleshoot.proxy.ProxyUtils;
import org.littleshoot.proxy.RelayListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for handling all HTTP requests from the browser to the proxy.
 * 
 * Note this class only ever handles a single connection from the browser.
 * The browser can and will, however, send requests to multiple hosts using
 * that same connection, i.e. it will send a request to host B once a request
 * to host A has completed.
 */
public class HttpRequestHandler extends SimpleChannelUpstreamHandler 
    implements RelayListener {

    private final static Logger log = 
        LoggerFactory.getLogger(HttpRequestHandler.class);
    private volatile boolean readingChunks;
    
    private int browserToProxyConnections = 0;
    
    private final Map<String, ChannelFuture> endpointsToChannelFutures = 
        new ConcurrentHashMap<String, ChannelFuture>();
    
    private volatile int messagesReceived = 0;
    
    private volatile int numWebConnections = 0;
    
    /**
     * Note, we *can* receive requests for multiple different sites from the
     * same connection from the browser, so the host and port most certainly
     * does change.
     * 
     * Why do we need to store it? We need it to lookup the appropriate 
     * external connection to send HTTP chunks to.
     */
    private String hostAndPort;
    
    private final ClientSocketChannelFactory clientSocketChannelFactory =
        new NioClientSocketChannelFactory(
            Executors.newCachedThreadPool(),
            Executors.newCachedThreadPool());
    
    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        messagesReceived++;
        log.info("Received "+messagesReceived+" total messages");
        if (!readingChunks) {
            processMessage(ctx, me);
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
        final ChannelFuture cf = 
            endpointsToChannelFutures.get(hostAndPort);
        
        // We don't necessarily know the channel is connected yet!! This can
        // happen if the client sends a chunk directly after the initial 
        // request.
        if (cf.getChannel().isConnected()) {
            cf.getChannel().write(chunk);
        }
        else {
            cf.addListener(new ChannelFutureListener() {
                
                public void operationComplete(final ChannelFuture future) 
                    throws Exception {
                    cf.getChannel().write(chunk);
                }
            });
        }
    }

    private void processMessage(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        final HttpRequest request = (HttpRequest) me.getMessage();
        
        log.info("Got request: {} on channel: "+me.getChannel(), request);
        
        // Check if we are running in proxy chain mode and modify request 
        // accordingly
        final HttpRequest httpRequestCopy = ProxyUtils.copyHttpRequest(request, 
            false);
        
        this.hostAndPort = ProxyUtils.parseHostAndPort(request);
        
        final Channel inboundChannel = me.getChannel();
        
        final class OnConnect {
            public ChannelFuture onConnect(final ChannelFuture cf) {
                if (httpRequestCopy.getMethod() != HttpMethod.CONNECT) {
                    return cf.getChannel().write(httpRequestCopy);
                }
                else {
                    writeConnectResponse(ctx, request, cf.getChannel());
                    return cf;
                }
            }
        }
     
        final OnConnect onConnect = new OnConnect();
        
        // We synchronize to avoid creating duplicate connections to the
        // same host, which we shouldn't for a single connection from the
        // browser. Note the synchronization here is short-lived, however,
        // due to the asynchronous connection establishment.
        synchronized (endpointsToChannelFutures) {
            final ChannelFuture curFuture = 
                endpointsToChannelFutures.get(hostAndPort);
            if (curFuture != null) {
                log.info("Using exising connection...");
                if (curFuture.getChannel().isConnected()) {
                    onConnect.onConnect(curFuture);
                }
                else {
                    final ChannelFutureListener cfl = new ChannelFutureListener() {
                        public void operationComplete(final ChannelFuture future)
                            throws Exception {
                            onConnect.onConnect(curFuture);
                        }
                    };
                    curFuture.addListener(cfl);
                }
            }
            else {
                log.info("Establishing new connection");
                /*
                final ChannelFutureListener closedCfl = new ChannelFutureListener() {
                    public void operationComplete(final ChannelFuture closed) 
                        throws Exception {
                        endpointsToChannelFutures.remove(hostAndPort);
                    }
                };
                */
                final ChannelFuture cf = 
                    newChannelFuture(httpRequestCopy, inboundChannel);
                endpointsToChannelFutures.put(hostAndPort, cf);
                cf.addListener(new ChannelFutureListener() {
                    public void operationComplete(final ChannelFuture future)
                        throws Exception {
                        final Channel channel = future.getChannel();
                        //channelGroup.add(channel);
                        if (future.isSuccess()) {
                            log.info("Connected successfully to: {}", channel);
                            log.info("Writing message on channel...");
                            final ChannelFuture wf = onConnect.onConnect(cf);
                            wf.addListener(new ChannelFutureListener() {
                                public void operationComplete(final ChannelFuture wcf)
                                    throws Exception {
                                    log.info("Finished write: "+wcf+ " to: "+
                                        httpRequestCopy.getMethod()+" "+
                                        httpRequestCopy.getUri());
                                }
                            });
                        }
                        else {
                            log.info("Could not connect to "+hostAndPort, 
                                future.getCause());
                            if (browserToProxyConnections == 1) {
                                log.warn("Closing browser to proxy channel " +
                                    "after not connecting to: {}", hostAndPort);
                                me.getChannel().close();
                                endpointsToChannelFutures.remove(hostAndPort);
                            }
                        }
                    }
                });
            }
        }
            
        if (request.isChunked()) {
            readingChunks = true;
        }
    }

    private void writeConnectResponse(final ChannelHandlerContext ctx, 
        final HttpRequest httpRequest, final Channel outgoingChannel) {
        final int port = ProxyUtils.parsePort(httpRequest);
        final Channel browserToProxyChannel = ctx.getChannel();
        
        // TODO: We should really only allow access on 443, but this breaks
        // what a lot of browsers do in practice.
        //if (port != 443) {
        if (port < 0) {
            log.warn("Connecting on port other than 443!!");
            final String statusLine = "HTTP/1.1 502 Proxy Error\r\n";
            ProxyUtils.writeResponse(browserToProxyChannel, statusLine, 
                ProxyUtils.PROXY_ERROR_HEADERS);
        }
        else {
            browserToProxyChannel.setReadable(false);
            
            // We need to modify both the pipeline encoders and decoders for the
            // browser to proxy channel *and* the encoders and decoders for the
            // proxy to external site channel.
            ctx.getPipeline().remove("encoder");
            ctx.getPipeline().remove("decoder");
            ctx.getPipeline().remove("handler");
            
            ctx.getPipeline().addLast("handler", 
                new HttpConnectRelayingHandler(outgoingChannel, null));
            
            final String statusLine = "HTTP/1.1 200 Connection established\r\n";
            ProxyUtils.writeResponse(browserToProxyChannel, statusLine, 
                ProxyUtils.CONNECT_OK_HEADERS);
            
            browserToProxyChannel.setReadable(true);
        }
    }

    private ChannelFuture newChannelFuture(final HttpRequest httpRequest, 
        final Channel browserToProxyChannel) {
        this.numWebConnections++;
        final String host;
        final int port;
        if (hostAndPort.contains(":")) {
            host = StringUtils.substringBefore(hostAndPort, ":");
            final String portString = 
                StringUtils.substringAfter(hostAndPort, ":");
            port = Integer.parseInt(portString);
        }
        else {
            host = hostAndPort;
            port = 80;
        }
        
        // Configure the client.
        final ClientBootstrap cb = 
            new ClientBootstrap(this.clientSocketChannelFactory);
        
        final ChannelPipelineFactory cpf;
        if (httpRequest.getMethod() == HttpMethod.CONNECT) {
            // In the case of CONNECT, we just want to relay all data in both 
            // directions. We SHOULD make sure this is traffic on a reasonable
            // port, however, such as 80 or 443, to reduce security risks.
            cpf = new ChannelPipelineFactory() {
                public ChannelPipeline getPipeline() throws Exception {
                    // Create a default pipeline implementation.
                    final ChannelPipeline pipeline = pipeline();
                    pipeline.addLast("handler", 
                        new HttpConnectRelayingHandler(browserToProxyChannel,
                            null));
                    return pipeline;
                }
            };
        }
        else {
            cpf = newDefaultRelayPipeline(httpRequest, browserToProxyChannel);
        }
            
        // Set up the event pipeline factory.
        cb.setPipelineFactory(cpf);
        cb.setOption("connectTimeoutMillis", 40*1000);
        

        // Start the connection attempt.
        log.info("Starting new connection to: "+hostAndPort);
        final ChannelFuture future = 
            cb.connect(new InetSocketAddress(host, port));
        return future;
    }
    
    private ChannelPipelineFactory newDefaultRelayPipeline(
        final HttpRequest httpRequest, final Channel browserToProxyChannel) {
        return new ChannelPipelineFactory() {
            public ChannelPipeline getPipeline() throws Exception {
                // Create a default pipeline implementation.
                final ChannelPipeline pipeline = pipeline();
                
                // We always include the request and response decoders
                // regardless of whether or not this is a URL we're 
                // filtering responses for. The reason is that we need to
                // follow connection closing rules based on the response
                // headers and HTTP version. 
                //
                // We also importantly need to follow the cache directives
                // in the HTTP response.
                pipeline.addLast("decoder", new HttpResponseDecoder());
                
                log.info("Querying for host and port: {}", hostAndPort);
                
                // The trick here is we need to determine whether or not
                // to cache responses based on the full URI of the request.
                // This request encoder will only get the URI without the
                // host, so we just have to be aware of that and construct
                // the original.
                final HttpRelayingHandler handler = 
                    new HttpRelayingHandler(browserToProxyChannel, 
                        null, HttpRequestHandler.this, hostAndPort);
                
                //final ProxyHttpRequestEncoder encoder = 
                //    new ProxyHttpRequestEncoder(handler);
                
                pipeline.addLast("encoder", new HttpRequestEncoder());
                pipeline.addLast("handler", handler);
                return pipeline;
            }
        };
    }

    
    public void onRelayChannelClose(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e, final Channel browserToProxyChannel, 
        final String key) {
        this.numWebConnections--;
        if (this.numWebConnections == 0) {
            log.info("Closing browser to proxy channel");
            browserToProxyChannel.close();
        }
        else {
            log.info("Not closing browser to proxy channel. Still "+
                this.numWebConnections+" connections...");
        }
        this.endpointsToChannelFutures.remove(key);
        
        if (numWebConnections != this.endpointsToChannelFutures.size()) {
            log.error("Something's amiss. We have "+numWebConnections+" and "+
                this.endpointsToChannelFutures.size()+" connections stored");
        }
        else {
            log.info("WEB CONNECTIONS COUNTS IN SYNC");
        }
    }
}
