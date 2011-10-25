package org.lantern;

import java.io.IOException;
import java.io.OutputStream;
import java.net.Socket;
import java.net.URI;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import org.apache.commons.io.IOUtils;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.lastbamboo.common.p2p.P2PClient;
import org.littleshoot.proxy.KeyStoreManager;
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
    
    private final AtomicReference<Socket> socketRef =
        new AtomicReference<Socket>();
    
    private volatile boolean startedCopying;
    
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
        if (this.socketRef.get() != null) {
            return true;
        }
        this.peerUri = this.proxy.getPeerProxy();
        if (this.peerUri != null) {
            threadedPeerSocket(this.peerUri);
        } else {
            log.info("No peer proxies!");
        }
        return false;
    }
    
    private void threadedPeerSocket(final URI peer) {
        final Thread thread = new Thread(new Runnable() {

            @Override
            public void run() {
                try {
                    final Socket sock = LanternUtils.openOutgoingPeerSocket(
                        peer, proxyStatusListener, p2pClient, 
                        peerFailureCount, true);
                    socketRef.set(sock);
                } catch (final IOException e) {
                    log.info("Could not create peer socket");
                }                
            }
            
        }, "Peer-Socket-Connection-Thread");
        thread.setDaemon(true);
        thread.start();
    }

    @Override
    public void processRequest(final Channel browserToProxyChannel,
        final ChannelHandlerContext ctx, final MessageEvent me) 
        throws IOException {
        browserToProxyChannel.setReadable(false);
        if (!startedCopying) {
            // We tell the socket not to record stats here because traffic
            // returning to the browser still goes through our encoder 
            // here (i.e. we haven't stripped the encoder to support 
            // CONNECT traffic).
            LanternUtils.startReading(this.socketRef.get(), 
                browserToProxyChannel, false);
            startedCopying = true;
        }
        final HttpRequest request = (HttpRequest) me.getMessage();

        log.info("Got an outbound socket on request handler hash {} to {}", 
            hashCode(), this.socketRef.get());
        
        final ChannelPipeline browserPipeline = 
            browserToProxyChannel.getPipeline();
        browserPipeline.remove("encoder");
        browserPipeline.remove("decoder");
        browserPipeline.remove("handler");
        browserPipeline.addLast("handler", 
            new SocketHttpConnectRelayingHandler(this.socketRef.get()));
            //new HttpConnectRelayingHandler(cf.getChannel(), null));
        
        // Lantern's a transparent proxy here, so we forward the HTTP CONNECT
        // message to the remote peer.
        final OutputStream os = this.socketRef.get().getOutputStream();
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
        IOUtils.closeQuietly(this.socketRef.get());
    }

    @Override
    public void processChunk(final ChannelHandlerContext ctx, 
        final MessageEvent me) throws IOException {
        throw new IllegalStateException(
            "Processing chunks on HTTP CONNECT relay?");
    }
}
