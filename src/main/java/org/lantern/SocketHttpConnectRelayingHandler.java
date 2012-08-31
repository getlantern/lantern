package org.lantern;

import java.net.Socket;

import org.apache.commons.io.IOUtils;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.ChannelHandler.Sharable;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.ChannelGroup;
import org.littleshoot.proxy.ProxyUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class that simply relays traffic the channel this is connected to to 
 * another channel passed in to the constructor.
 */
@Sharable
public class SocketHttpConnectRelayingHandler 
    extends SimpleChannelUpstreamHandler {
    
    private static final Logger LOG = 
        LoggerFactory.getLogger(SocketHttpConnectRelayingHandler.class);
    

    /**
     * The channel to relay to. This could be a connection from the browser
     * to the proxy or it could be a connection from the proxy to an external
     * site.
     */
    private final Socket sock;


    private final ChannelGroup channelGroup;

    /**
     * Creates a new {@link SocketHttpConnectRelayingHandler} with the specified 
     * connection to relay to.
     * 
     * @param sock The socket to relay to.
     * @param channelGroup Keeps track of channels to close on shutdown.
     */
    public SocketHttpConnectRelayingHandler(final Socket sock,
        final ChannelGroup channelGroup) {
        this.sock = sock;
        this.channelGroup = channelGroup;
    }

    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent e) throws Exception {
        final ChannelBuffer msg = (ChannelBuffer) e.getMessage();
        final byte[] data = LanternUtils.toRawBytes(msg);
        //LOG.info("Writing on CONNECT socket: "+new String(data));
        sock.getOutputStream().write(data);
    }

    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent cse) throws Exception {
        final Channel ch = cse.getChannel();
        LOG.info("New CONNECT channel opened: {}", ch);
        this.channelGroup.add(ch);
    }

    @Override
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) throws Exception {
        LOG.info("Got closed event on connection we're relaying: {}", 
            e.getChannel());
        IOUtils.closeQuietly(sock);
    }

    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        LOG.warn("Caught exception on connection we're relaying: "+
            e.getChannel(), e.getCause());
        ProxyUtils.closeOnFlush(e.getChannel());
        IOUtils.closeQuietly(sock);
    }
}
