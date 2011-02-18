package org.lantern;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.Socket;
import java.net.URI;
import java.nio.ByteBuffer;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.lastbamboo.common.offer.answer.NoAnswerException;
import org.lastbamboo.common.util.ByteBufferUtils;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handler that relays traffic to another proxy.
 */
public class PeerProxyRelayHandler extends SimpleChannelUpstreamHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private volatile long messagesReceived = 0L;

    private final URI peerUri;


    private Channel inboundChannel;

    private final ProxyStatusListener proxyStatusListener;

    private final XmppP2PClient p2pClient;

    private Socket outgoingSocket;
    
    private static Map<URI, Long> peerConnectionTimes =
        new ConcurrentHashMap<URI, Long>();
    
    /**
     * Map recording the number of consecutive connection failures for a
     * given peer. Note that a successful connection will reset this count
     * back to zero.
     */
    private static Map<URI, AtomicInteger> peerFailureCount =
        new ConcurrentHashMap<URI, AtomicInteger>();
    
    /**
     * Creates a new relayer to a peer proxy.
     * 
     * @param peerUri The URI of the peer to connect to.
     * @param proxyStatusListener The class to notify of changes in the proxy
     * status.
     * @param p2pClient The client for creating P2P connections.
     */
    public PeerProxyRelayHandler(final URI peerUri, 
        final ProxyStatusListener proxyStatusListener, 
        final XmppP2PClient p2pClient) {
        this.peerUri = peerUri;
        this.proxyStatusListener = proxyStatusListener;
        this.p2pClient = p2pClient;
    }
    
    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        messagesReceived++;
        log.info("Received {} total messages", messagesReceived);
        
        // We need to convert the Netty message to raw bytes for sending over
        // the socket.
        final ChannelBuffer msg = (ChannelBuffer) me.getMessage();
        final ByteBuffer buf = msg.toByteBuffer();
        final byte[] data = ByteBufferUtils.toRawBytes(buf);
        try {
            log.info("Writing {}", new String(data));
            final OutputStream os = this.outgoingSocket.getOutputStream();
            os.write(data);
        } catch (final IOException e) {
            // They probably just closed the connection, as they will in
            // many cases.
            //this.proxyStatusListener.onError(this.peerUri);
        }
    }
    
    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) {
        if (this.outgoingSocket != null) {
            log.error("Outbound channel already assigned?");
        }
        this.inboundChannel = e.getChannel();
        
        // This ensures we won't read any messages before we've successfully
        // created the socket.
        this.inboundChannel.setReadable(false);

        // Start the connection attempt.
        try {
            log.info("Creating a new socket to {}", this.peerUri);
            this.outgoingSocket = this.p2pClient.newSocket(this.peerUri);
            peerConnectionTimes.put(this.peerUri, System.currentTimeMillis());
            peerFailureCount.put(this.peerUri, new AtomicInteger(0));
            inboundChannel.setReadable(true);
            startReading();
        } catch (final NoAnswerException nae) {
            // This is tricky, as it can mean two things. First, it can mean
            // the XMPP message was somehow lost. Second, it can also mean
            // the other side is actually not there and didn't respond as a
            // result.
            log.info("Did not get answer!! Closing channel from browser", nae);
            final AtomicInteger count = peerFailureCount.get(this.peerUri);
            if (count == null) {
                log.info("Incrementing failure count");
                peerFailureCount.put(this.peerUri, new AtomicInteger(0));
            }
            else if (count.incrementAndGet() > 5) {
                log.info("Got a bunch of failures in a row to this peer. " +
                    "Removing it.");
                
                // We still reset it back to zero. Note this all should 
                // ideally never happen, and we should be able to use the
                // XMPP presence alerts to determine if peers are still valid
                // or not.
                peerFailureCount.put(this.peerUri, new AtomicInteger(0));
                proxyStatusListener.onCouldNotConnectToPeer(peerUri);
            } 
            this.inboundChannel.close();
        } catch (final IOException ioe) {
            proxyStatusListener.onCouldNotConnectToPeer(peerUri);
            log.warn("Could not connect to peer", ioe);
            this.inboundChannel.close();
        }
    }
    
    @Override 
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent cse) {
        log.info("Got inbound channel closed. Closing outbound.");
        closeOutgoing();
    }

    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) {
        log.error("Caught exception on INBOUND channel", e.getCause());
        LanternUtils.closeOnFlush(this.inboundChannel);
        closeOutgoing();
    }
    
    private void closeOutgoing() {
        log.info("Closing outgoing socket");
        if (this.outgoingSocket != null) {
            try {
                this.outgoingSocket.close();
            } catch (final IOException e) {
                log.info("Exception closing socket", e);
            }
        }
    }
    
    private void startReading() {
        final Runnable runner = new Runnable() {

            public void run() {
                final byte[] buffer = new byte[4096];
                long count = 0;
                int n = 0;
                try {
                    final InputStream is = outgoingSocket.getInputStream();
                    while (-1 != (n = is.read(buffer))) {
                        //log.info("Writing response data: {}", new String(buffer, 0, n));
                        // We need to make a copy of the buffer here because
                        // the writes are asynchronous, so the bytes can
                        // otherwise get scrambled.
                        final ChannelBuffer buf =
                            ChannelBuffers.copiedBuffer(buffer, 0, n);
                        inboundChannel.write(buf);
                        count += n;
                        log.info("In while");
                    }
                    log.info("Out of while");
                    LanternUtils.closeOnFlush(inboundChannel);

                } catch (final IOException e) {
                    log.info("Exception relaying peer data back to browser",e);
                    LanternUtils.closeOnFlush(inboundChannel);
                    
                    // The other side probably just closed the connection!!
                    
                    //inboundChannel.close();
                    //proxyStatusListener.onError(peerUri);
                    
                }
            }
        };
        final Thread peerReadingThread = 
            new Thread(runner, "Peer-Data-Reading-Thread");
        peerReadingThread.setDaemon(true);
        peerReadingThread.start();
    }

}
