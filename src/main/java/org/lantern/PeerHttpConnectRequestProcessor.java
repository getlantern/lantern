package org.lantern;

import java.io.IOException;
import java.io.OutputStream;
import java.net.Socket;
import java.util.concurrent.atomic.AtomicBoolean;

import org.apache.commons.io.IOUtils;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * HTTP request processor that sends requests to peers.
 */
public class PeerHttpConnectRequestProcessor implements HttpRequestProcessor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final AtomicBoolean configured = new AtomicBoolean(false);

    private final Socket sock;

    private final ChannelGroup channelGroup;

    public PeerHttpConnectRequestProcessor(final Socket sock,
        final ChannelGroup channelGroup) {
        this.sock = sock;
        this.channelGroup = channelGroup;
    }

    @Override
    public boolean processRequest(final Channel browserToProxyChannel,
        final ChannelHandlerContext ctx, final MessageEvent me) 
        throws IOException {
        
        if (!configured.getAndSet(true)) {
            browserToProxyChannel.setReadable(false);
            // We tell the socket to record stats here because traffic
            // returning to the browser is just shuttled through 
            // a SocketHttpConnectRelayingHandler and the normal 
            // encoder that records stats is removed from the 
            // browserToProxyChannel pipeline.
            LanternUtils.startReading(this.sock, browserToProxyChannel, true);
            
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

        log.info("Processing request...");
        // Lantern's a transparent proxy here, so we forward the HTTP CONNECT
        // message to the remote peer.
        final OutputStream os = this.sock.getOutputStream();
        final HttpRequest request = (HttpRequest) me.getMessage();
        try {
            final byte[] data = LanternUtils.toByteBuffer(request, ctx);
            log.info("Writing data on peer socket: {}", new String(data, "UTF-8"));
            os.write(data);
            // shady, hard to know if it's really been done
            LanternHub.statsTracker().addUpBytesViaProxies(data.length, this.sock);
        } catch (final Exception e) {
            log.error("Could not encode request?", e);
        }
        return true;
    }

    @Override
    public void close() {
        IOUtils.closeQuietly(this.sock);
    }

    @Override
    public boolean processChunk(final ChannelHandlerContext ctx, 
        final MessageEvent me) throws IOException {
        log.error("Processing chunks on HTTP CONNECT relay?");
        throw new IllegalStateException(
            "Processing chunks on HTTP CONNECT relay?");
    }
}
