package org.mg.client;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.ByteBuffer;

import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.lastbamboo.common.util.ByteBufferUtils;
import org.mg.common.MgUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handler that relays traffic to another proxy.
 */
public class RawSocketProxyRelayHandler extends SimpleChannelUpstreamHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private volatile long messagesReceived = 0L;

    private Channel inboundChannel;

    private final ProxyStatusListener proxyStatusListener;

    private Socket outgoingSocket;

    private final InetSocketAddress proxy;
    
    
    public RawSocketProxyRelayHandler(final InetSocketAddress proxy,
        final ProxyStatusListener proxyStatusListener) {
        this.proxy = proxy;
        this.proxyStatusListener = proxyStatusListener;
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
            //log.info("Creating a new socket to {}", this.peerUri);
            this.outgoingSocket = new Socket();
            this.outgoingSocket.connect(this.proxy, 40000);
            inboundChannel.setReadable(true);
            startReading();
        } catch (final IOException ioe) {
            //proxyStatusListener.onCouldNotConnectToPeer(proxy);
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
                    MgUtils.closeOnFlush(inboundChannel);

                } catch (final IOException e) {
                    log.info("Exception relaying peer data back to browser",e);
                    MgUtils.closeOnFlush(inboundChannel);
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
