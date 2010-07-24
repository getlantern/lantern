package org.mg.client;

import java.nio.ByteBuffer;
import java.nio.channels.ClosedChannelException;
import java.util.Collection;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.codec.binary.Base64;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpChunk;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.ChatManager;
import org.jivesoftware.smack.MessageListener;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.packet.Message;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for handling all HTTP requests from the browser to the proxy.
 */
public class HttpRequestHandler extends SimpleChannelUpstreamHandler {

    private final static Logger log = 
        LoggerFactory.getLogger(HttpRequestHandler.class);
    private static final String HTTP_KEY = "HTTP";
    
    private volatile boolean readingChunks;
    
    private static int totalBrowserToProxyConnections = 0;
    private int browserToProxyConnections = 0;
    
    private final Map<String, ChannelFuture> endpointsToChannelFutures = 
        new ConcurrentHashMap<String, ChannelFuture>();
    
    private volatile int messagesReceived = 0;
    
    /**
     * Note, we *can* receive requests for multiple different sites from the
     * same connection from the browser, so the host and port most certainly
     * does change.
     * 
     * Why do we need to store it? We need it to lookup the appropriate 
     * external connection to send HTTP chunks to.
     */
    private String hostAndPort;
    private final ChannelGroup channelGroup;

    private final ClientSocketChannelFactory clientChannelFactory;
    private Chat chat;
    
    /**
     * Creates a new class for handling HTTP requests with the specified
     * authentication manager.
     * 
     * @param channelGroup The group of channels for keeping track of all
     * channels we've opened.
     * @param clientChannelFactory The common channel factory for clients.
     * @param conn The XMPP connection. 
     */
    public HttpRequestHandler(final ChannelGroup channelGroup, 
        final ClientSocketChannelFactory clientChannelFactory, 
        final XMPPConnection conn) {
        this.channelGroup = channelGroup;
        this.clientChannelFactory = clientChannelFactory;
        final ChatManager chatmanager = conn.getChatManager();
        
        this.chat = 
            chatmanager.createChat("mglittleshoot@gmail.com", 
            new MessageListener() {
                public void processMessage(final Chat chat, final Message msg) {
                    log.info("Received message: " + msg);
                    // We need to grab the HTTP data from the message and send
                    // it to the browser.
                    final String data = (String) msg.getProperty(HTTP_KEY);
                    if (data == null) {
                        log.warn("No HTTP data");
                        return;
                    }
                }
            });
        
    }
    
    private static final class LocalHttpRequestEncoder 
        extends HttpRequestEncoder {
        
        @Override
        protected Object encode(final ChannelHandlerContext chc, 
            final Channel channel, final Object msg) throws Exception {
            return super.encode(chc, channel, msg);
        }
    }

    private Channel localChannel = new LocalChannel();
    
    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        messagesReceived++;
        log.info("Received "+messagesReceived+" total messages");

        final LocalHttpRequestEncoder encoder = new LocalHttpRequestEncoder();
        try {
            final ChannelBuffer encoded = 
                (ChannelBuffer) encoder.encode(ctx, localChannel, me.getMessage());
            final ByteBuffer buf = encoded.toByteBuffer();
            final byte[] raw = toRawBytes(buf);
            final String base64 = Base64.encodeBase64String(raw);
            final Message msg = new Message();
            msg.setProperty(HTTP_KEY, base64);
            
            // The other side will also need to know where the request came
            // from to differentiate incoming HTTP connections.
            msg.setProperty("LOCAL-IP", ctx.getChannel().getLocalAddress());
            msg.setProperty("REMOTE-IP", ctx.getChannel().getRemoteAddress());
            
            this.chat.sendMessage(msg);
            log.info("Sent message!!");
        } catch (Exception e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
        
        if (!readingChunks) {
            processMessage(ctx, me);
        } 
        else {
            processChunk(ctx, me);
        }
    }
    
    public static byte[] toRawBytes(final ByteBuffer buf) {
        final int mark = buf.position();
        final byte[] bytes = new byte[buf.remaining()];
        buf.get(bytes);
        
        buf.position(mark);
        return bytes;
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

    }

    
    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent cse) throws Exception {
        final Channel inboundChannel = cse.getChannel();
        log.info("New channel opened: {}", inboundChannel);
        totalBrowserToProxyConnections++;
        browserToProxyConnections++;
        log.info("Now "+totalBrowserToProxyConnections+" browser to proxy channels...");
        log.info("Now this class has "+browserToProxyConnections+" browser to proxy channels...");
        
        // We need to keep track of the channel so we can close it at the end.
        this.channelGroup.add(inboundChannel);
    }
    
    @Override
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent cse) {
        log.info("Channel closed: {}", cse.getChannel());
        totalBrowserToProxyConnections--;
        browserToProxyConnections--;
        log.info("Now "+totalBrowserToProxyConnections+" total browser to proxy channels...");
        log.info("Now this class has "+browserToProxyConnections+" browser to proxy channels...");
        
        // The following should always be the case with
        // @ChannelPipelineCoverage("one")
        if (browserToProxyConnections == 0) {
            log.info("Closing all proxy to web channels for this browser " +
                "to proxy connection!!!");
            final Collection<ChannelFuture> futures = 
                this.endpointsToChannelFutures.values();
            for (final ChannelFuture future : futures) {
                final Channel ch = future.getChannel();
                if (ch.isOpen()) {
                    future.getChannel().close();
                }
            }
        }
    }

    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        final Channel channel = e.getChannel();
        final Throwable cause = e.getCause();
        if (cause instanceof ClosedChannelException) {
            log.info("Caught an exception on browser to proxy channel: "+
                channel, cause);
        }
        else {
            log.warn("Caught an exception on browser to proxy channel: "+
                channel, cause);
        }
        if (channel.isOpen()) {
            closeOnFlush(channel);
        }
    }
    
    /**
     * Closes the specified channel after all queued write requests are flushed.
     */
    private static void closeOnFlush(final Channel ch) {
        log.info("Closing on flush: {}", ch);
        if (ch.isConnected()) {
            ch.write(ChannelBuffers.EMPTY_BUFFER).addListener(
                ChannelFutureListener.CLOSE);
        }
    }
}
