package org.lantern.client;

import java.nio.ByteBuffer;
import java.nio.channels.ClosedChannelException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
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
import org.jivesoftware.smack.MessageListener;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Message;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for handling all HTTP requests from the browser to the proxy.
 */
public class HttpRequestHandler extends SimpleChannelUpstreamHandler 
    implements MessageListener {

    private final static Logger log = 
        LoggerFactory.getLogger(HttpRequestHandler.class);
    
    private static int totalBrowserToProxyConnections = 0;
    private int browserToProxyConnections = 0;
    
    private volatile int messagesReceived = 0;
    
    private final ChannelGroup channelGroup;

    private final Chat chat;
    
    private long outgoingSequenceNumber = 0L;
    private Channel browserToProxyChannel;

    private final String macAddress;
    
    private long bytesSent = 0L;
    
    private long expectedSequenceNumber = 0L;
    
    private final Map<Long, Message> sequenceMap = 
        new ConcurrentHashMap<Long, Message>();
    
    /**
     * Unique key identifying this connection.
     */
    private final String key;
    
    /**
     * Creates a new class for handling HTTP requests with the specified
     * authentication manager.
     * 
     * @param channelGroup The group of channels for keeping track of all
     * channels we've opened.
     * @param clientChannelFactory The common channel factory for clients.
     * @param conn The XMPP connection. 
     * @param macAddress The unique MAC address for this host.
     */
    public HttpRequestHandler(final ChannelGroup channelGroup, 
        final String macAddress, final Chat chat) {
        this.channelGroup = channelGroup;
        this.macAddress = macAddress;
        this.chat = chat;
        this.key = newKey(this.macAddress, this.hashCode());
    }
    
    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        messagesReceived++;
        log.info("Received "+messagesReceived+" total messages");
        //final HttpRequest request = (HttpRequest) me.getMessage();
        //final long contentLength = HttpHeaders.getContentLength(request);
        
        //log.info("Content-Length: "+contentLength);
        
        final Channel ch = ctx.getChannel();
        if (this.browserToProxyChannel != null && this.browserToProxyChannel != ch) {
            log.error("Got message on a different channel??!");
        }
        this.browserToProxyChannel = ch;
        try {
            final ChannelBuffer cb = (ChannelBuffer) me.getMessage();
            final ByteBuffer buf = cb.toByteBuffer();
            final byte[] raw = toRawBytes(buf);
            final Message msg = newMessage();
            msg.setProperty(XmppMessageConstants.HTTP, 
                Base64.encodeBase64URLSafeString(raw));
            this.chat.sendMessage(msg);
            log.info("Sent XMPP message!!");
        } catch (final XMPPException e) {
            log.error("Error sending message", e);
        }
    }
    
    @Override
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent cse) {
        log.info("Channel closed: {}", cse.getChannel());
        totalBrowserToProxyConnections--;
        browserToProxyConnections--;
        log.info("Now "+totalBrowserToProxyConnections+
            " total browser to proxy channels...");
        log.info("Now this class has "+browserToProxyConnections+
            " browser to proxy channels...");
        
        // The following should always be the case with
        // @ChannelPipelineCoverage("one")
        // We need to notify the remote server that the client connection 
        // has closed.
        if (browserToProxyConnections == 0) {
            log.warn("Closing all proxy to web channels for this browser " +
                "to proxy connection!!!");
            
            final Message msg = newMessage();
            msg.setProperty(XmppMessageConstants.CLOSE, "true");

            try {
                this.chat.sendMessage(msg);
                log.info("Sent close message");
            } catch (final XMPPException e) {
                log.error("Error sending close message!!", e);
            }
        }
    }
    
    private Message newMessage() {
        final Message msg = new Message();
        
        // The other side will also need to know where the request came
        // from to differentiate incoming HTTP connections.
        msg.setProperty(XmppMessageConstants.MAC, this.macAddress);
        msg.setProperty(XmppMessageConstants.HASHCODE, 
            String.valueOf(this.hashCode()));
        
        // We set the sequence number in case the XMPP server delivers the 
        // packets out of order for any reason.
        msg.setProperty(XmppMessageConstants.SEQ, outgoingSequenceNumber);
        outgoingSequenceNumber++;
        return msg;
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

    private final Object writeLock = new Object();
    
    public void processMessage(final Chat ignored, final Message msg) {
        log.info("Received message with props: {}", 
            msg.getPropertyNames());
        final long sequenceNumber = 
            (Long) msg.getProperty(XmppMessageConstants.SEQ);
        log.info("SEQUENCE NUMBER: "+sequenceNumber+ " FOR: "+hashCode() + 
            " BROWSER TO PROXY CHANNEL: "+browserToProxyChannel);

        // If the other side is sending the close directive, we 
        // need to close the connection to the browser.
        if (isClose(msg)) {
            // This will happen quite often, as the XMPP server won't 
            // necessarily deliver messages in order.
            if (sequenceNumber != expectedSequenceNumber) {
                log.info("BAD SEQUENCE NUMBER ON CLOSE. " +
                    "EXPECTED "+expectedSequenceNumber+
                    " BUT WAS "+sequenceNumber);
                sequenceMap.put(sequenceNumber, msg);
            }
            else {
                log.info("Got CLOSE. Closing channel to browser: {}", 
                    browserToProxyChannel);
                if (browserToProxyChannel.isOpen()) {
                    log.info("Remaining messages: "+this.sequenceMap);
                    closeOnFlush(browserToProxyChannel);
                }
            }
            return;
        }
        
        // We need to grab the HTTP data from the message and send
        // it to the browser.
        final String data = (String) msg.getProperty(XmppMessageConstants.HTTP);
        if (data == null) {
            log.warn("No HTTP data");
            return;
        }
        final String mac = (String) msg.getProperty(XmppMessageConstants.MAC);
        final String hc = (String) msg.getProperty(XmppMessageConstants.HASHCODE);
        final String localKey = newKey(mac, Integer.parseInt(hc));
        if (!localKey.equals(this.key)) {
            log.error("RECEIVED A MESSAGE THAT'S NOT FOR US?!?!?!");
            log.error("\nOUR KEY IS:   "+this.key+
                      "\nBUT RECEIVED: "+localKey);
        }
    
        synchronized (writeLock) {
            if (sequenceNumber != expectedSequenceNumber) {
                log.error("BAD SEQUENCE NUMBER. " +
                    "EXPECTED "+expectedSequenceNumber+
                    " BUT WAS "+sequenceNumber+" FOR KEY: "+localKey);
                sequenceMap.put(sequenceNumber, msg);
            }
            else {
                writeData(msg);
                expectedSequenceNumber++;
                
                while (sequenceMap.containsKey(expectedSequenceNumber)) {
                    log.info("WRITING SEQUENCE number: "+
                        expectedSequenceNumber);
                    final Message curMessage = 
                        sequenceMap.remove(expectedSequenceNumber);
                    
                    // It's possible to get the close event itself out of
                    // order, so we need to check if the stored message is a
                    // close message.
                    if (isClose(curMessage)) {
                        log.info("Detected out-of-order CLOSE message!");
                        closeOnFlush(browserToProxyChannel);
                        break;
                    }
                    writeData(curMessage);
                    expectedSequenceNumber++;
                }
            }
        }
    }

    private boolean isClose(final Message msg) {
        final String close = (String) msg.getProperty(XmppMessageConstants.CLOSE);
        // If the other side is sending the close directive, we 
        // need to close the connection to the browser.
        return 
            StringUtils.isNotBlank(close) && 
            close.trim().equalsIgnoreCase("true");
    }

    private void writeData(final Message msg) {
        final String data = (String) msg.getProperty(XmppMessageConstants.HTTP);
        final byte[] raw = 
            Base64.decodeBase64(data.getBytes(CharsetUtil.UTF_8));
        
        final String md5 = toMd5(raw);
        final String expected = 
            (String) msg.getProperty(XmppMessageConstants.MD5);
        if (!md5.equals(expected)) {
            log.error("MD-5s not equal!! Expected:\n'"+expected+
                "'\nBut was:\n'"+md5+"'");
        }
        
        //log.info("Wrapping data: {}", new String(raw, CharsetUtil.UTF_8));
        bytesSent += raw.length;
        log.info("Now sent "+bytesSent+" bytes after "+raw.length+" new");
        final ChannelBuffer cb = ChannelBuffers.wrappedBuffer(raw);
        
        if (browserToProxyChannel.isOpen()) {
            browserToProxyChannel.write(cb);
        }
        else {
            log.info("Not sending data to closed browser connection");
        }
    }
    
    private String newKey(final String mac, final int hc) {
        return mac.trim() + hc;
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
}
