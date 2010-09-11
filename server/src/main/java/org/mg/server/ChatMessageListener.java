package org.mg.server;

import static org.jboss.netty.channel.Channels.pipeline;

import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Collection;
import java.util.HashSet;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFactory;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.util.CharsetUtil;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Message;
import org.jivesoftware.smackx.ChatState;
import org.jivesoftware.smackx.ChatStateListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for listening for messages for a specific chat.
 */
public class ChatMessageListener implements ChatStateListener {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Collection<String> removedConnections = 
        new HashSet<String>();
    
    private final ConcurrentHashMap<Long, Message> sentMessages =
        new ConcurrentHashMap<Long, Message>();
    
    private final Map<String, ChannelFuture> proxyConnections;

    private final Chat chat;

    private final XMPPConnection conn;

    private final String MAC_ADDRESS;

    private final ChannelFactory channelFactory;
    
    private volatile long expectedSequenceNumber = 0L;

    public ChatMessageListener(
        final Map<String, ChannelFuture> proxyConnections, 
        final Chat chat, final XMPPConnection conn, final String macAddress, 
        final ChannelFactory channelFactory) {
        this.proxyConnections = proxyConnections;
        this.chat = chat;
        this.conn = conn;
        this.MAC_ADDRESS = macAddress;
        this.channelFactory = channelFactory;
    }

    public void processMessage(final Chat ch, final Message msg) {
        log.info("Got message!!");
        log.info("Property names: {}", msg.getPropertyNames());
        final long seq = (Long) msg.getProperty("SEQ");
        log.info("SEQUENCE #: {}", seq);
        log.info("HASHCODE #: {}", msg.getProperty("HASHCODE"));
        
        log.info("FROM: {}",msg.getFrom());
        log.info("TO: {}",msg.getTo());
        final String smac = (String) msg.getProperty("SMAC");
        log.info("SMAC: {}", smac);
        
        if (seq != this.expectedSequenceNumber) {
            log.error("GOT UNEXPECTED SEQUENCE NUMBER. EXPECTED "+
                expectedSequenceNumber+" BUT WAS "+seq+" WITH PARTICIPANT "+
                ch.getParticipant());
        }
        
        expectedSequenceNumber++;
        if (StringUtils.isNotBlank(smac) && 
            smac.trim().equals(MAC_ADDRESS)) {
            log.warn("MESSAGE FROM OURSELVES -- ATTEMPTING TO SEND BACK!!");
            log.warn("Connected?? "+conn.isConnected());
            /*
            synchronized (sentMessages) {
                if (sentMessages.isEmpty()) {
                    log.warn("No sent messages");
                }
                else {
                    final Message sent = 
                        sentMessages.values().iterator().next();
                    log.warn("Also randomly sending message with sequence number: "+sent.getProperty("SEQ"));
                    try {
                        chat.sendMessage(sent);
                    } catch (final XMPPException e) {
                        log.error("XMPP error!!", e);
                    }
                }
            }
            
            msg.setTo(chat.getParticipant());
            msg.setFrom(conn.getUser());
            log.info("NEW FROM: {}",msg.getFrom());
            log.info("NEW TO: {}",msg.getTo());
            try {
                chat.sendMessage(msg);
            } catch (final XMPPException e) {
                log.error("XMPP error!!", e);
            }
            */
            return;
        }
        
        final String closeString = 
            (String) msg.getProperty("CLOSE");
        
        log.info("Close value: {}", closeString);
        final boolean close;
        if (StringUtils.isNotBlank(closeString) &&
            closeString.trim().equalsIgnoreCase("true")) {
            log.info("Got close true");
            close = true;
        }
        else {
            close = false;
            final String data = (String) msg.getProperty("HTTP");
            if (StringUtils.isBlank(data)) {
                log.warn("HTTP IS BLANK?? IGNORING...");
                return;
            }
        }
        
        if (close) {
            log.info("Received close from client...closing " +
                "connection to the proxy for HASHCODE: {}", 
                msg.getProperty("HASHCODE"));
            final String key = messageKey(msg);
            final ChannelFuture cf = proxyConnections.get(key);
            
            if (cf != null) {
                cf.getChannel().close();
                removedConnections.add(key);
            }
            else {
                log.error("Got close for connection we don't " +
                    "know about! Removed keys are: {}", 
                    removedConnections);
            }
            return;
        }
        log.info("Getting channel future...");
        final ChannelFuture cf = getChannelFuture(msg, close);
        log.info("Got channel: {}", cf);
        if (cf == null) {
            log.info("Null channel future! Returning");
            return;
        }
        
        // TODO: Check the sequence number??
        final ChannelBuffer cb = xmppToHttpChannelBuffer(msg);

        if (cf.getChannel().isConnected()) {
            cf.getChannel().write(cb);
        }
        else {
            cf.addListener(new ChannelFutureListener() {
                public void operationComplete(
                    final ChannelFuture future) 
                    throws Exception {
                    cf.getChannel().write(cb);
                }
            });
        }
    }

    public void stateChanged(final Chat monitoredChat, 
        final ChatState state) {
        log.info("Got chat state changed: ", state);
    }
    

    private ChannelBuffer xmppToHttpChannelBuffer(final Message msg) {
        final String data = (String) msg.getProperty("HTTP");
        final byte[] raw = 
            Base64.decodeBase64(data.getBytes(CharsetUtil.UTF_8));
        return ChannelBuffers.wrappedBuffer(raw);
    }
    
    /**
     * This gets a channel to connect to the local HTTP proxy on. This is 
     * slightly complex, as we're trying to mimic the state as if this HTTP
     * request is coming in to a "normal" LittleProxy instance instead of
     * having the traffic tunneled through XMPP. So we create a separate 
     * connection to the proxy just as those separate connections were made
     * from the browser to the proxy originally on the remote end.
     * 
     * If there's already an existing connection mimicking the original 
     * connection, we use that.
     *
     * @param key The key for the remote IP/port pair.
     * @param chat The chat session across Google Talk -- we need this to 
     * send responses back to the original caller.
     * @param close Whether or not this is a message to close the connection -
     * we don't want to open a new connection if it is.
     * @param connections The connections to the local proxy that are 
     * associated with this chat.
     * @param removedConnections Keeps track of connections we've removed --
     * for debugging.
     * @param conn The XMPP connection.
     * @param sentMessages Messages we've sent out.
     * @return The {@link ChannelFuture} that will connect to the local
     * LittleProxy instance.
     */
    private ChannelFuture getChannelFuture(final Message message, 
        final boolean close) {
        
        // The other side will also need to know where the 
        // request came from to differentiate incoming HTTP 
        // connections.
        log.info("Getting properties...");
        
        // Note these will fail if the original properties were not set as
        // strings.
        final String key = messageKey(message);
        if (StringUtils.isBlank(key)) {
            log.error("Could not create key");
            return null;
        }
        
        log.info("Getting channel future for key: {}", key);
        synchronized (this.proxyConnections) {
            if (proxyConnections.containsKey(key)) {
                log.info("Using existing connection");
                return proxyConnections.get(key);
            }
            if (close) {
                // We've likely already closed the connection in this case.
                log.warn("Returning null channel on close call");
                return null;
            }
            if (removedConnections.contains(key)) {
                log.warn("KEY IS IN REMOVED CONNECTIONS: "+key);
            }
            // Configure the client.
            final ClientBootstrap cb = new ClientBootstrap(this.channelFactory);
            
            final ChannelPipelineFactory cpf = new ChannelPipelineFactory() {
                public ChannelPipeline getPipeline() throws Exception {
                    // Create a default pipeline implementation.
                    final ChannelPipeline pipeline = pipeline();
                    
                    final class HttpChatRelay extends SimpleChannelUpstreamHandler {
                        private long sequenceNumber = 0L;
                        
                        @Override
                        public void messageReceived(
                            final ChannelHandlerContext ctx, 
                            final MessageEvent me) throws Exception {
                            //log.info("HTTP message received from proxy on " +
                            //    "relayer: {}", me.getMessage());
                            final Message msg = new Message();
                            final ByteBuffer buf = 
                                ((ChannelBuffer) me.getMessage()).toByteBuffer();
                            final byte[] raw = toRawBytes(buf);
                            final String base64 = 
                                Base64.encodeBase64URLSafeString(raw);
                            
                            log.info("Connection ID: {}", conn.getConnectionID());
                            log.info("Connection host: {}", conn.getHost());
                            log.info("Connection service name: {}", conn.getServiceName());
                            log.info("Connection user: {}", conn.getUser());
                            msg.setTo(chat.getParticipant());
                            msg.setFrom(conn.getUser());
                            msg.setProperty("HTTP", base64);
                            msg.setProperty("MD5", toMd5(raw));
                            msg.setProperty("SEQ", sequenceNumber);
                            msg.setProperty("HASHCODE", 
                                message.getProperty("HASHCODE"));
                            msg.setProperty("MAC", message.getProperty("MAC"));
                            
                            // This is the server-side MAC address. This is
                            // useful because there are odd cases where XMPP
                            // servers echo back our own messages, and we
                            // want to ignore them.
                            log.info("Setting SMAC to: {}", MAC_ADDRESS);
                            msg.setProperty("SMAC", MAC_ADDRESS);
                            
                            log.info("Sending to: {}", chat.getParticipant());
                            log.info("Sending SEQUENCE #: "+sequenceNumber);
                            sentMessages.put(sequenceNumber, msg);
                            chat.sendMessage(msg);
                            sequenceNumber++;
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
                            msg.setProperty("HASHCODE", message.getProperty("HASHCODE"));
                            msg.setProperty("MAC", message.getProperty("MAC"));
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
                            log.info("Setting SMAC to: {}", MAC_ADDRESS);
                            msg.setProperty("SMAC", MAC_ADDRESS);
                            
                            try {
                                chat.sendMessage(msg);
                            } catch (final XMPPException e) {
                                log.warn("Error sending close message", e);
                            }
                            removedConnections.add(key);
                            proxyConnections.remove(key);
                        }
                        
                        @Override
                        public void exceptionCaught(final ChannelHandlerContext ctx, 
                            final ExceptionEvent e) throws Exception {
                            log.warn("Caught exception on C in A->B->C->D " +
                                "chain...", e.getCause());
                            if (e.getChannel().isOpen()) {
                                log.warn("Closing open connection");
                                closeOnFlush(e.getChannel());
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
                    
                    pipeline.addLast("handler", new HttpChatRelay());
                    return pipeline;
                }
            };
                
            // Set up the event pipeline factory.
            cb.setPipelineFactory(cpf);
            cb.setOption("connectTimeoutMillis", 40*1000);

            log.info("Connecting to localhost proxy");
            final ChannelFuture future = 
                cb.connect(new InetSocketAddress("127.0.0.1", 7777));
            proxyConnections.put(key, future);
            return future;
        }
    }
    
    private String messageKey(final Message message) {
        final String mac = (String) message.getProperty("MAC");
        final String hc = (String) message.getProperty("HASHCODE");

        // We can sometimes get messages back that were not intended for us.
        // Just ignore them.
        if (mac == null || hc == null) {
            log.error("Message not intended for us?!?!?\n" +
                "Null MAC and/or HASH and to: "+message.getTo());
            return null;
        }
        final String key = mac + hc;
        return key;
    }
    
    /**
     * Closes the specified channel after all queued write requests are flushed.
     */
    private void closeOnFlush(final Channel ch) {
        log.info("Closing channel on flush: {}", ch);
        if (ch.isConnected()) {
            ch.write(ChannelBuffers.EMPTY_BUFFER).addListener(
                ChannelFutureListener.CLOSE);
        }
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

    public static byte[] toRawBytes(final ByteBuffer buf) {
        final int mark = buf.position();
        final byte[] bytes = new byte[buf.remaining()];
        buf.get(bytes);
        buf.position(mark);
        return bytes;
    }
}

