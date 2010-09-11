package org.mg.server;

import java.nio.ByteBuffer;
import java.util.Map;

import org.apache.commons.codec.binary.Base64;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Message;
import org.mg.common.MgUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * This class processes responses from the connection to the local HTTP
 * proxy. It wraps the responses in XMPP messages and sends them back to
 * the original requester.
 */
public class LocalProxyResponseToXmppRelayer extends SimpleChannelUpstreamHandler {
    private long sequenceNumber = 0L;
    
    private final Logger log = LoggerFactory.getLogger(getClass());

    private final Message incomingXmppMessage;

    private final XMPPConnection conn;

    private final Chat chat;

    private final String macAddress;

    private final Map<Long, Message> sentMessages;
    
    private static volatile int totalSentMessages = 0;
    private static volatile int totalHttpBytesSent = 0;
    
    public LocalProxyResponseToXmppRelayer(final XMPPConnection conn, 
        final Chat chat, final Message incomingXmppMessage, 
        final String macAddress, final Map<Long,Message> sentMessages) {
        this.conn = conn;
        this.chat = chat;
        this.incomingXmppMessage = incomingXmppMessage;
        this.macAddress = macAddress;
        this.sentMessages = sentMessages;
    }
    
    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent me) {
        log.info("HTTP message received from proxy on relayer...");
        final Message msg = new Message();
        final ByteBuffer buf = ((ChannelBuffer) me.getMessage()).toByteBuffer();
        final byte[] raw = MgUtils.toRawBytes(buf);
        final String base64 = Base64.encodeBase64URLSafeString(raw);
        
        log.info("Connection ID: {}", conn.getConnectionID());
        log.info("Connection host: {}", conn.getHost());
        log.info("Connection service name: {}", conn.getServiceName());
        log.info("Connection user: {}", conn.getUser());
        msg.setTo(chat.getParticipant());
        msg.setFrom(conn.getUser());
        msg.setProperty("HTTP", base64);
        msg.setProperty("MD5", MgUtils.toMd5(raw));
        msg.setProperty("SEQ", sequenceNumber);
        msg.setProperty("HASHCODE",incomingXmppMessage.getProperty("HASHCODE"));
        msg.setProperty("MAC", incomingXmppMessage.getProperty("MAC"));
        
        // This is the server-side MAC address. This is
        // useful because there are odd cases where XMPP
        // servers echo back our own messages, and we
        // want to ignore them.
        log.info("Setting SMAC to: {}", macAddress);
        msg.setProperty("SMAC", macAddress);
        
        log.info("Sending to: {}", chat.getParticipant());
        log.info("Sending SEQUENCE #: "+sequenceNumber);
        sentMessages.put(sequenceNumber, msg);
        try {
            chat.sendMessage(msg);
            totalSentMessages++;
            totalHttpBytesSent += raw.length;
            sequenceNumber++;
            log.info("TOTAL SENT MESSAGES: "+totalSentMessages);
            log.info("TOTAL HTTP BYTES SENT: "+totalHttpBytesSent);
        } catch (final XMPPException e) {
            log.error("XMPP error sending a message", e);
        }
    }
    
    @Override
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent cse) {
        // We need to send the CLOSE directive to the other
        // side VIA google talk to simulate the proxy 
        // closing the connection to the browser.
        log.info("Got channel closed on C in A->B->C->D chain...");
        log.info("Sending close message");
        final Message msg = new Message();
        msg.setProperty("HASHCODE", incomingXmppMessage.getProperty("HASHCODE"));
        msg.setProperty("MAC", incomingXmppMessage.getProperty("MAC"));
        msg.setFrom(conn.getUser());
        
        // We set the sequence number so the client knows
        // how many total messages to expect. This is 
        // necessary because the XMPP server can deliver 
        // messages out of order.
        msg.setProperty("SEQ", sequenceNumber);
        msg.setProperty("CLOSE", "true");
        
        // This is the server-side MAC address. This is
        // useful because there are odd cases where XMPP
        // servers echo back our own messages, and we
        // want to ignore them.
        log.info("Setting SMAC to: {}", macAddress);
        msg.setProperty("SMAC", macAddress);
        
        try {
            chat.sendMessage(msg);
            totalSentMessages++;
        } catch (final XMPPException e) {
            log.warn("Error sending close message", e);
        }
    }
    
    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx, 
        final ExceptionEvent e) throws Exception {
        log.warn("Caught exception on C in A->B->C->D " +
            "chain...", e.getCause());
        if (e.getChannel().isOpen()) {
            log.warn("Closing open connection");
            MgUtils.closeOnFlush(e.getChannel());
        }
        else {
            // We've seen odd cases where channels seem to 
            // continually attempt connections. Make sure 
            // we explicitly close the connection here.
            log.info("Channel is not open...ignoring");
            //log.warn("Closing connection even though " +
            //    "isOpen is false");
            //e.getChannel().close();
        }
    }
}
