package org.mg.client;

import java.io.IOException;
import java.io.OutputStream;
import java.net.Socket;
import java.net.URI;
import java.nio.ByteBuffer;

import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.lastbamboo.common.util.ByteBufferUtils;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.mg.common.MgUtils;
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
        final MessageEvent me) throws IOException {
        messagesReceived++;
        log.info("Received {} total messages", messagesReceived);
        
        // We need to convert the Netty message to raw bytes for sending over
        // the socket.
        final ChannelBuffer msg = (ChannelBuffer) me.getMessage();
        final ByteBuffer buf = msg.toByteBuffer();
        final byte[] data = ByteBufferUtils.toRawBytes(buf);
        final OutputStream os = this.outgoingSocket.getOutputStream();
        os.write(data);
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
            inboundChannel.setReadable(true);
        } catch (final IOException ioe) {
            proxyStatusListener.onCouldNotConnectToPeer(peerUri);
            log.warn("Could not connection to peer", ioe);
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
        MgUtils.closeOnFlush(this.inboundChannel);
        closeOutgoing();
    }
    
    private void closeOutgoing() {
        if (this.outgoingSocket != null) {
            try {
                this.outgoingSocket.close();
            } catch (final IOException e) {
                log.info("Exception closing socket", e);
            }
        }
    }
    
    /*
    private static class OutboundHandler extends SimpleChannelUpstreamHandler {

        private final Logger log = LoggerFactory.getLogger(getClass());
        
        private final Channel inboundChannel;

        OutboundHandler(final Channel inboundChannel) {
            this.inboundChannel = inboundChannel;
        }

        @Override
        public void messageReceived(final ChannelHandlerContext ctx, 
            final MessageEvent e) throws Exception {
            final ChannelBuffer msg = (ChannelBuffer) e.getMessage();
            inboundChannel.write(msg);
        }

        @Override
        public void channelClosed(final ChannelHandlerContext ctx, 
            final ChannelStateEvent e) throws Exception {
            MgUtils.closeOnFlush(inboundChannel);
        }

        @Override
        public void exceptionCaught(final ChannelHandlerContext ctx, 
            final ExceptionEvent e) throws Exception {
            log.error("Caught exception on OUTBOUND channel", e.getCause());
            MgUtils.closeOnFlush(e.getChannel());
        }
    }
    */

}
