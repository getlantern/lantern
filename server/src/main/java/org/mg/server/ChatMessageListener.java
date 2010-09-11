package org.mg.server;

import static org.jboss.netty.channel.Channels.pipeline;

import java.net.InetSocketAddress;
import java.util.Collection;
import java.util.HashSet;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.ChannelFactory;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.util.CharsetUtil;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.XMPPConnection;
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
            
            log.error("MESSAGE FROM OURSELVES -- NOT GOOD!! MESSAGE BODY: {}", 
                msg.getBodies());
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
        
        final String closeString = (String) msg.getProperty("CLOSE");
        
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
        
        final ChannelBuffer cb = unwrap(msg);

        if (cf.getChannel().isConnected()) {
            cf.getChannel().write(cb);
        }
        else {
            cf.addListener(new ChannelFutureListener() {
                public void operationComplete(final ChannelFuture future) 
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
    

    private ChannelBuffer unwrap(final Message msg) {
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
                    
                    pipeline.addLast("handler", 
                        new LocalProxyResponseToXmppRelayer(conn, chat, message, MAC_ADDRESS, 
                            sentMessages));
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
    
}

