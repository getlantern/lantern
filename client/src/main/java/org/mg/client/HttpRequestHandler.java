package org.mg.client;

import java.nio.ByteBuffer;
import java.nio.channels.ClosedChannelException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.List;

import org.apache.commons.codec.binary.Base64;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.util.CharsetUtil;
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
    
    private static int totalBrowserToProxyConnections = 0;
    private int browserToProxyConnections = 0;
    
    private volatile int messagesReceived = 0;
    
    private final ChannelGroup channelGroup;

    private Chat chat;
    
    private long outgoingSequenceNumber = 0L;
    private Channel browserToProxyChannel;
    private final XMPPConnection conn;
    private final String macAddress;
    
    private long lastSequenceNumber = -1L;
    private long bytesSent = 0L;
    
    /**
     * Creates a new class for handling HTTP requests with the specified
     * authentication manager.
     * 
     * @param channelGroup The group of channels for keeping track of all
     * channels we've opened.
     * @param clientChannelFactory The common channel factory for clients.
     * @param conn The XMPP connection. 
     * @param mgJids The IDs of MG to connect to. 
     * @param macAddress The unique MAC address for this host.
     * @param mgJids 
     */
    public HttpRequestHandler(final ChannelGroup channelGroup, 
        final XMPPConnection conn, final String macAddress, 
        final Collection<String> mgJids) {
        
        this.channelGroup = channelGroup;
        this.conn = conn;
        this.macAddress = macAddress;
        log.info("Using TLS: "+conn.isSecureConnection());
        final ChatManager chatmanager = conn.getChatManager();
        
        final List<String> strs;
        synchronized (mgJids) {
            strs = new ArrayList<String>(mgJids);
        }
        
        Collections.shuffle(strs);
        final String id = strs.iterator().next();
        
        this.chat = 
            chatmanager.createChat(id,
            new MessageListener() {
                public void processMessage(final Chat ch, final Message msg) {
                    log.info("Received message with props: {}", 
                        msg.getPropertyNames());
                    final String close = (String) msg.getProperty("CLOSE");

                    // If the other side is sending the close directive, we 
                    // need to close the connection to the browser.
                    if (close != null && close.trim().equalsIgnoreCase("true")) {
                        log.info("Got CLOSE. Closing channel to browser.");
                        browserToProxyChannel.close();
                        return;
                    }
                    
                    // We need to grab the HTTP data from the message and send
                    // it to the browser.
                    final String data = (String) msg.getProperty(HTTP_KEY);
                    if (data == null) {
                        log.warn("No HTTP data");
                        return;
                    }
                    final ChannelBuffer cb = xmppToHttpChannelBuffer(msg);
                    browserToProxyChannel.write(cb);
                }
            });
    }
    
    private ChannelBuffer xmppToHttpChannelBuffer(final Message msg) {
        
        final long sequenceNumber = (Long) msg.getProperty("SEQ");
        if (lastSequenceNumber != -1L) {
            final long expected = lastSequenceNumber + 1;
            if (sequenceNumber != expected) {
                log.error("BAD SEQUENCE NUMBER. EXPECTED "+expected+
                    " BUT WAS "+sequenceNumber);
            }
        }
        lastSequenceNumber = sequenceNumber;
        
        final String data = (String) msg.getProperty(HTTP_KEY);
        final byte[] raw = 
            Base64.decodeBase64(data.getBytes(CharsetUtil.UTF_8));
        
        final String md5 = toMd5(raw);
        final String expected = (String) msg.getProperty("MD5");
        if (!md5.equals(expected)) {
            log.error("MD-5s not equal!! Expected:\n'"+expected+"'\nBut was:\n'"+md5+"'");
        }
        else {
            log.info("MD-5s match!!");
        }
        
        log.info("Wrapping data: {}", new String(raw, CharsetUtil.UTF_8));
        bytesSent += raw.length;
        log.info("Now sent "+bytesSent+" bytes after "+raw.length+" new");
        return ChannelBuffers.wrappedBuffer(raw);
    }
    
    private String toMd5(final byte[] raw) {
        try {
            final MessageDigest md = MessageDigest.getInstance("MD5");
            final byte[] digest = md.digest(raw);
            return Base64.encodeBase64URLSafeString(digest);
        } catch (final NoSuchAlgorithmException e) {
            log.error("No MD5 -- will never happen", e);
            return "NO MD5";
        }
    }
    
    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        messagesReceived++;
        log.info("Received "+messagesReceived+" total messages");

        final Channel ch = ctx.getChannel();
        if (this.browserToProxyChannel != null && this.browserToProxyChannel != ch) {
            log.error("Got message on a different channel??!");
        }
        this.browserToProxyChannel = ch;
        try {
            final ChannelBuffer cb = (ChannelBuffer) me.getMessage();
            final ByteBuffer buf = cb.toByteBuffer();
            final byte[] raw = toRawBytes(buf);
            final String base64 = Base64.encodeBase64URLSafeString(raw);
            final Message msg = new Message();
            msg.setProperty(HTTP_KEY, base64);
            
            // The other side will also need to know where the request came
            // from to differentiate incoming HTTP connections.
            msg.setProperty("LOCAL-IP", ch.getLocalAddress().toString());
            msg.setProperty("REMOTE-IP", ch.getRemoteAddress().toString());
            msg.setProperty("MAC", this.macAddress);
            msg.setProperty("HASHCODE", String.valueOf(this.hashCode()));
            
            // We set the sequence number in case the server delivers the 
            // packets out of order for any reason.
            msg.setProperty("SEQ", outgoingSequenceNumber);
            
            this.chat.sendMessage(msg);
            outgoingSequenceNumber++;
            log.info("Sent message!!");
        } catch (final Exception e) {
            log.error("Could not relay message", e);
        }
    }
    
    public static byte[] toRawBytes(final ByteBuffer buf) {
        final int mark = buf.position();
        final byte[] bytes = new byte[buf.remaining()];
        buf.get(bytes);
        buf.position(mark);
        return bytes;
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
        
        log.info("Disconnecting from XMPP server...");
        this.conn.disconnect();
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
