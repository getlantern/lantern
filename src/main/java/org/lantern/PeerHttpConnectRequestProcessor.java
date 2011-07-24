package org.lantern;

import java.io.IOException;
import java.io.OutputStream;
import java.net.Socket;
import java.net.URI;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.commons.io.IOUtils;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.lastbamboo.common.p2p.P2PClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * HTTP request processor that sends requests to peers.
 */
public class PeerHttpConnectRequestProcessor implements HttpRequestProcessor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private URI peerUri;
    private final ProxyStatusListener proxyStatusListener;
    private final P2PClient p2pClient;
    
    private Socket outgoingSocket;
    
    /**
     * Map recording the number of consecutive connection failures for a
     * given peer. Note that a successful connection will reset this count
     * back to zero.
     */
    private static Map<URI, AtomicInteger> peerFailureCount =
        new ConcurrentHashMap<URI, AtomicInteger>();

    private final Proxy proxy;

    public PeerHttpConnectRequestProcessor(final Proxy proxy, 
        final ProxyStatusListener proxyStatusListener,
        final P2PClient p2pClient){
        this.proxy = proxy;
        this.proxyStatusListener = proxyStatusListener;
        this.p2pClient = p2pClient;
    }

    @Override
    public boolean hasProxy() {
        if (this.peerUri != null) {
            return true;
        }
        this.peerUri = this.proxy.getPeerProxy();
        if (this.peerUri != null) {
            return true;
        }
        log.info("No peer proxies!");
        return false;
    }

    @Override
    public void processRequest(final Channel browserToProxyChannel,
        final ChannelHandlerContext ctx, final MessageEvent me) 
        throws IOException {
        browserToProxyChannel.setReadable(false);
        final HttpRequest request = (HttpRequest) me.getMessage();
        
        if (this.outgoingSocket == null) {
            // We can pass raw traffic here because this is all tunneled SSL
            // using HTTP CONNECT.
            try {
                // NOTE: THIS SHOULD NEVER BE USING OUR CIPHERS
                // We tell the socket to record stats in this case because
                // we've stripped our encoder that would otherwise track 'em.
                this.outgoingSocket = LanternUtils.openRawOutgoingPeerSocket(
                    browserToProxyChannel, this.peerUri, 
                    this.proxyStatusListener, this.p2pClient, peerFailureCount,
                    true);
            } catch (final IOException e) {
                // Notify the requester an outgoing connection has failed.
                // We notify the listener in this case because it's a CONNECT
                // request -- the remote side should never close it. 
                this.proxyStatusListener.onCouldNotConnectToPeer(this.peerUri);
                throw e;
            }
        }

        log.info("Got an outbound socket on request handler hash {} to {}", 
            hashCode(), this.outgoingSocket);
        
        final ChannelPipeline browserPipeline = 
            browserToProxyChannel.getPipeline();
        browserPipeline.remove("encoder");
        browserPipeline.remove("decoder");
        browserPipeline.remove("handler");
        browserPipeline.addLast("handler", 
            new SocketHttpConnectRelayingHandler(this.outgoingSocket));
            //new HttpConnectRelayingHandler(cf.getChannel(), null));
        
        // Lantern's a transparent proxy here, so we forward the HTTP CONNECT
        // message to the remote peer.
        final OutputStream os = this.outgoingSocket.getOutputStream();
        try {
            final byte[] data = LanternUtils.toByteBuffer(request, ctx);
            log.info("Writing data on peer socket: {}", new String(data));
            os.write(data);
        } catch (final Exception e) {
            log.error("Could not encode request?", e);
        }
        browserToProxyChannel.setReadable(true);
    }

    @Override
    public void close() {
        IOUtils.closeQuietly(this.outgoingSocket);
    }

    @Override
    public void processChunk(final ChannelHandlerContext ctx, 
        final MessageEvent me) throws IOException {
        throw new IllegalStateException(
            "Processing chunks on HTTP CONNECT relay?");
    }
}
