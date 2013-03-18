package org.lantern;

import java.io.IOException;
import java.io.OutputStream;
import java.net.Socket;
import java.util.concurrent.atomic.AtomicBoolean;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandler;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.Channels;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.codec.http.HttpResponseDecoder;
import org.littleshoot.proxy.ProxyUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * HTTP request processor that sends requests to peers and 
 * writes HttpResponses to the browerToProxy channel. 
 * 
 * This differs from PeerHttpRequestProcessor in that it
 * wraps the littleshoot peer socket in a netty Channel with 
 * a pipeline that decodes the HttpResponse rather than 
 * relaying raw bytes. We do this so that we can observe
 * characteristics of the response in the main browserToProxy
 * channel pipeline, eg observing Set-Cookie responses.
 */
public class PeerChannelHttpRequestProcessor implements HttpRequestProcessor {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private volatile PeerSocketChannel peerChannel;
    
    private final Socket sock;
    private final PeerSink peerSink = new PeerSink();
    
    private final AtomicBoolean configured = new AtomicBoolean(false);

    private final ChannelGroup channelGroup;

    private final ByteTracker byteTracker;

    private final LanternSocketsUtil socketsUtil;

    public PeerChannelHttpRequestProcessor(final Socket sock, 
        final ChannelGroup channelGroup, final ByteTracker byteTracker,
        final LanternSocketsUtil socketsUtil) {
        this.sock = sock;
        this.channelGroup = channelGroup;
        this.byteTracker = byteTracker;
        this.socketsUtil = socketsUtil;
    }

    @Override
    public boolean processRequest(final Channel browserToProxyChannel,
        final ChannelHandlerContext ctx, final HttpRequest request) 
        throws IOException {
        final HttpMethod method = request.getMethod();

        final ChannelPipeline pipeline = Channels.pipeline();
        if (!configured.getAndSet(true)) {
            
            if (method == HttpMethod.CONNECT) {
                configureConnect(browserToProxyChannel);
            } else {
                configureStandard(pipeline, browserToProxyChannel);
            }
            
        }
        
        if (method == HttpMethod.CONNECT) {
            try {
                final OutputStream os = this.sock.getOutputStream();
                final byte[] data = LanternUtils.toByteBuffer(request, ctx);
                log.debug("Writing {} bytes on peer socket...", data.length);
                os.write(data);
                
                // Remember this could be any kind of underlying socket here, 
                // including a UDP socket with an OutputStream that might not
                // have truly written then bytes even though it's theoretically
                // blocking.
                byteTracker.addUpBytes(data.length);
            } catch (final IOException e) {
                log.error("Could not write to stream?", e);
                return false;
            } catch (final Exception e) {
                log.error("Could not encode request?", e);
                return false;
            }
        } else {
            this.peerChannel = new PeerSocketChannel(pipeline, peerSink, sock);
            this.peerChannel.simulateConnect();
            Channels.write(peerChannel, request);
        }

        
        // We return true in all these case to preserve the behavior before
        // the change to return a boolean. The point of returning a boolean
        // was more to consolidate the check for the existence of a proxy with
        // the request processing.
        return true;
    }

    private void configureConnect(final Channel browserToProxyChannel) {
        browserToProxyChannel.setReadable(false);
        // We tell the socket to record stats here because traffic
        // returning to the browser is just shuttled through 
        // a SocketHttpConnectRelayingHandler and the normal 
        // encoder that records stats is removed from the 
        // browserToProxyChannel pipeline.
        this.socketsUtil.startReading(this.sock, browserToProxyChannel, true);
        
        log.info("Got an outbound socket on request handler hash {} to {}", 
            hashCode(), this.sock);
            
        final ChannelPipeline browserPipeline = 
            browserToProxyChannel.getPipeline();
        browserPipeline.remove("encoder");
        browserPipeline.remove("decoder");
        browserPipeline.remove("handler");
        
        browserPipeline.addLast("handler", 
            new SocketHttpConnectRelayingHandler(this.sock, 
                this.channelGroup));
        browserToProxyChannel.setReadable(true);
    }

    private void configureStandard(final ChannelPipeline pipeline, 
        final Channel browserToProxyChannel) {
        final ChannelHandler stats = new StatsTrackingHandler() {
            @Override
            public void addUpBytes(final long bytes) {
                byteTracker.addUpBytes(bytes);
            }
            @Override
            public void addDownBytes(final long bytes) {
                byteTracker.addDownBytes(bytes);
            }
        };
        
        pipeline.addLast("stats", stats);
        pipeline.addLast("decoder", new HttpResponseDecoder());
        pipeline.addLast("encoder", new HttpRequestEncoder());
        pipeline.addLast("relay", 
            new RelayToBrowserHandler(browserToProxyChannel));
    }

    /*
    @Override
    public boolean processChunk(final ChannelHandlerContext ctx, 
        final HttpChunk chunk) throws IOException {
        Channels.write(peerChannel, chunk);
        return true;
    }
    */

    @Override
    public void close() {
        ProxyUtils.closeOnFlush(peerChannel);
    }

    // This is similar to OutboundHandler, unclear if we need similar complexity
    // here for range requests, the old version relayed raw bytes, so this 
    // seems sufficient.
    private class RelayToBrowserHandler extends SimpleChannelUpstreamHandler {
        
        private final Channel browserToProxyChannel;
        
        public RelayToBrowserHandler(final Channel browserToProxyChannel) {
            this.browserToProxyChannel = browserToProxyChannel;
        }

        @Override
        public void messageReceived(ChannelHandlerContext ctx, MessageEvent me) {
            browserToProxyChannel.write(me.getMessage());
        }
        
        @Override
        public void channelOpen(final ChannelHandlerContext ctx, 
            final ChannelStateEvent cse) throws Exception {
            final Channel ch = cse.getChannel();
            log.info("New channel opened: {}", ch);
            channelGroup.add(ch);
        }
        
        @Override
         public void channelClosed(final ChannelHandlerContext ctx, 
             final ChannelStateEvent e) throws Exception {
             log.info("Channel to peer proxy closed, closing browserToProxy channel.");
             ProxyUtils.closeOnFlush(browserToProxyChannel);
         }

         @Override
         public void exceptionCaught(final ChannelHandlerContext ctx, 
             final ExceptionEvent e) throws Exception {
             log.error("Caught exception on peer proxy channel", e.getCause());
             Channels.close(e.getChannel()); 
         }
    }
}
