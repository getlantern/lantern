package org.lantern;

import static org.jboss.netty.buffer.ChannelBuffers.copiedBuffer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.Socket;
import java.net.URI;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.commons.io.IOUtils;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.util.CharsetUtil;
import org.lastbamboo.common.p2p.P2PClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * HTTP request processor that sends requests to peers.
 */
public class PeerHttpConnectRequestProcessor implements HttpRequestProcessor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    //space ' '
    static final byte SP = 32;
    
    /**
     * Colon ':'
     */
     static final byte COLON = 58;
    
    /**
     * Carriage return
     */
    static final byte CR = 13;

    /**
     * Equals '='
     */
    static final byte EQUALS = 61;

    /**
     * Line feed character
     */
    static final byte LF = 10;

    /**
     * carriage return line feed
     */
    static final byte[] CRLF = new byte[] { CR, LF };
    
    private static final ChannelBuffer LAST_CHUNK =
        copiedBuffer("0\r\n\r\n", CharsetUtil.US_ASCII);
    
    private URI peerInfo;
    private final ProxyStatusListener proxyStatusListener;
    private final P2PClient p2pClient;
    
    private Socket socket;
    
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

    public boolean hasProxy() {
        if (this.peerInfo != null) {
            return true;
        }
        this.peerInfo = this.proxy.getPeerProxy();
        if (this.peerInfo != null) {
            return true;
        }
        log.info("No peer proxies!");
        return false;
    }

    public void processRequest(final Channel browserToProxyChannel,
        final ChannelHandlerContext ctx, final MessageEvent me) 
        throws IOException {
        if (this.socket == null) {
            this.socket = LanternUtils.openOutgoingPeerSocket(
                browserToProxyChannel, this.peerInfo, ctx, 
                this.proxyStatusListener, this.p2pClient, peerFailureCount);
        }
        final HttpRequest request = (HttpRequest) me.getMessage();
        browserToProxyChannel.setReadable(false);
        
        if (this.socket == null) {
            this.socket = LanternUtils.openOutgoingPeerSocket(
                browserToProxyChannel, this.peerInfo, ctx, 
                this.proxyStatusListener, this.p2pClient, peerFailureCount);
        }

        log.info("Got an outbound channel on: {}", hashCode());
        final ChannelPipeline browserPipeline = ctx.getPipeline();
        browserPipeline.remove("encoder");
        browserPipeline.remove("decoder");
        browserPipeline.remove("handler");
        browserPipeline.addLast("handler", 
            new SocketHttpConnectRelayingHandler(this.socket));
            //new HttpConnectRelayingHandler(cf.getChannel(), null));
        
        
        browserToProxyChannel.setReadable(true);
        final OutputStream os = this.socket.getOutputStream();
        try {
            final byte[] data = LanternUtils.toByteBuffer(request, ctx);
            os.write(data);
        } catch (final Exception e) {
            log.error("Could not encode request?", e);
            // Notify the requester an outgoing connection has failed.
        }
    }

    public void close() {
        IOUtils.closeQuietly(this.socket);
    }

    public void processChunk(ChannelHandlerContext ctx, MessageEvent me)
            throws IOException {
        // TODO Auto-generated method stub
        
    }
}
