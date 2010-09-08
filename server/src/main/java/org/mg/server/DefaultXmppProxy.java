package org.mg.server;

import static org.jboss.netty.channel.Channels.pipeline;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.NetworkInterface;
import java.net.Socket;
import java.net.SocketException;
import java.net.UnknownHostException;
import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.Map;
import java.util.Properties;
import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;

import javax.net.SocketFactory;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.jboss.netty.bootstrap.ClientBootstrap;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.util.CharsetUtil;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.ChatManager;
import org.jivesoftware.smack.ChatManagerListener;
import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.ConnectionListener;
import org.jivesoftware.smack.MessageListener;
import org.jivesoftware.smack.PacketListener;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Message;
import org.jivesoftware.smack.packet.Packet;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smackx.ChatState;
import org.jivesoftware.smackx.ChatStateListener;
import org.jivesoftware.smackx.ChatStateManager;
import org.littleshoot.proxy.Launcher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class DefaultXmppProxy implements XmppProxy {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final ClientSocketChannelFactory channelFactory =
        new NioClientSocketChannelFactory(
            Executors.newCachedThreadPool(),
            Executors.newCachedThreadPool());
    
    private static final String MAC_ADDRESS;
    
    static {
        String tempMac;
        try {
            tempMac = getMacAddress();
        } catch (final SocketException e) {
            e.printStackTrace();
            tempMac = String.valueOf(RandomUtils.nextLong());
        }
        MAC_ADDRESS = tempMac.trim();
    }
    
    public DefaultXmppProxy() {
        // Start the HTTP proxy server that we relay data to. It has more
        // developed logic for handling different types of requests, and we'd
        // otherwise have to duplicate that here.
        Launcher.main("7777");
    }
    
    public void start() throws XMPPException, IOException {
        final Properties props = new Properties();
        final File propsDir = new File(System.getProperty("user.home"), ".mg");
        final File propsFile = new File(propsDir, "mg.properties");

        if (!propsFile.isFile()) {
            System.err.println("No properties file found at "+propsFile+
                ". That file is required and must contain a property for " +
                "'user' and 'pass'.");
            System.exit(0);
        }
        props.load(new FileInputStream(propsFile));
        final String user = props.getProperty("google.server.user");
        final String pass = props.getProperty("google.server.pwd");
        
        final Collection<XMPPConnection> xmppConnections = 
            new ArrayList<XMPPConnection>();
        
        for (int i = 0; i < 10; i++) {
            // We create a bunch of connections to allow us to process as much
            // incoming data as possible.
            final XMPPConnection xmpp = newConnection(user, pass);
            xmppConnections.add(xmpp);
            log.info("Created connection for user: {}", xmpp.getUser());
        }
        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {

            public void run() {
                for (final XMPPConnection conn : xmppConnections) {
                    log.info("Disconnecting user: {}", conn.getUser());
                    conn.disconnect();
                }
            }
            
        }, "XMPP-Disconnect-On-Shutdown"));
    }
    
    private XMPPConnection newConnection(final String user, final String pass) {
        for (int i = 0; i < 10; i++) {
            try {
                return newSingleConnection(user, pass);
            } catch (final XMPPException e) {
                log.error("Could not create XMPP connection", e);
            }
        }
        throw new RuntimeException("Could not connect to XMPP server");
    }

    private XMPPConnection newSingleConnection(final String user, 
        final String pass) throws XMPPException {
        final ConnectionConfiguration config = 
            new ConnectionConfiguration("talk.google.com", 5222, "gmail.com");
        config.setCompressionEnabled(true);
        config.setReconnectionAllowed(true);
        config.setSocketFactory(new SocketFactory() {
            
            @Override
            public Socket createSocket(final InetAddress host, 
                final int port, final InetAddress localHost,
                final int localPort) throws IOException {
                // We ignore the local port binding.
                return createSocket(host, port);
            }
            
            @Override
            public Socket createSocket(final String host, 
                final int port, final InetAddress localHost,
                final int localPort)
                throws IOException, UnknownHostException {
                // We ignore the local port binding.
                return createSocket(host, port);
            }
            
            @Override
            public Socket createSocket(final InetAddress host, int port) 
                throws IOException {
                log.info("Creating socket");
                final Socket sock = new Socket();
                sock.connect(new InetSocketAddress(host, port), 40000);
                log.info("Socket connected");
                return sock;
            }
            
            @Override
            public Socket createSocket(final String host, final int port) 
                throws IOException, UnknownHostException {
                log.info("Creating socket");
                return createSocket(InetAddress.getByName(host), port);
            }
        });
        
        //final ConnectionConfiguration config = 
        //    new ConnectionConfiguration("talk.google.com", 5222, "gmail.com");
        //config.setCompressionEnabled(true);
        
        final XMPPConnection conn = new XMPPConnection(config);
        conn.connect();
        conn.login(user, pass, "MG");
        final Roster roster = conn.getRoster();
        roster.setSubscriptionMode(Roster.SubscriptionMode.accept_all);
        
        conn.addConnectionListener(new ConnectionListener() {

            public void connectionClosed() {
                log.warn("XMPP connection closed!!");
            }

            public void connectionClosedOnError(final Exception e) {
                log.warn("XMPP connection closed on error!!", e);
            }

            public void reconnectingIn(int seconds) {
                log.info("XMPP connection reconnecting...");
            }

            public void reconnectionFailed(final Exception e) {
                log.info("XMPP connection reconnection failed", e);
            }

            public void reconnectionSuccessful() {
                log.info("Reconnection succeeded!!");
            }
            
        });
        
        final ChatManager cm = conn.getChatManager();
        cm.addChatListener(new ChatManagerListener() {
            
            public void chatCreated(final Chat chat, 
                final boolean createdLocally) {
                log.info("Created a chat!!");
                
                final ConcurrentHashMap<String, ChannelFuture> proxyConnections =
                    new ConcurrentHashMap<String, ChannelFuture>();
                
                // We need to listen for the unavailability of clients we're 
                // chatting with so we can disconnect from their associated 
                // remote servers.
                final PacketListener pl = new PacketListener() {
                    public void processPacket(final Packet pack) {
                        if (!(pack instanceof Presence)) return;
                        final Presence pres = (Presence) pack;
                        final String from = pres.getFrom();
                        final String participant = chat.getParticipant();
                        //log.info("Comparing presence packet from "+from+
                        //    " to particant "+participant);
                        if (from.equals(participant) && !pres.isAvailable()) {
                            log.info("Closing all channels for this chat");
                            synchronized(proxyConnections) {
                                for (final ChannelFuture cf : proxyConnections.values()) {
                                    log.info("Closing channel to local proxy");
                                    cf.getChannel().close();
                                }
                            }
                        }
                    }
                };
                // Register the listener.
                conn.addPacketListener(pl, null);
                
                final ChatStateManager csm = ChatStateManager.getInstance(conn);
                final MessageListener ml = 
                    new ProxyMessageListener(proxyConnections, chat, conn);
                chat.addMessageListener(ml);
            }
        });
        return conn;
    }
    
    /**
     * Class for listening for messages for a specific chat.
     */
    private final class ProxyMessageListener implements ChatStateListener {
        
        private final Collection<String> removedConnections = 
            new HashSet<String>();
        
        private final ConcurrentHashMap<Long, Message> sentMessages =
            new ConcurrentHashMap<Long, Message>();
        
        private final Map<String, ChannelFuture> proxyConnections;

        private final Chat chat;

        private final XMPPConnection conn;

        public ProxyMessageListener(
            final Map<String, ChannelFuture> proxyConnections, 
            final Chat chat, final XMPPConnection conn) {
            this.proxyConnections = proxyConnections;
            this.chat = chat;
            this.conn = conn;
        }

        public void processMessage(final Chat ch, final Message msg) {
            log.info("Got message!!");
            log.info("Property names: {}", msg.getPropertyNames());
            log.info("SEQUENCE #: {}", msg.getProperty("SEQ"));
            log.info("HASHCODE #: {}", msg.getProperty("HASHCODE"));
            
            log.info("FROM: {}",msg.getFrom());
            log.info("TO: {}",msg.getTo());
            
            final String smac = (String) msg.getProperty("SMAC");
            log.info("SMAC: {}", smac);
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
            final ChannelFuture cf = 
                getChannelFuture(msg, chat, close, 
                    proxyConnections, removedConnections, conn,
                    sentMessages);
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
        final Chat chat, final boolean close, 
        final Map<String,ChannelFuture> connections, 
        final Collection<String> removedConnections, 
        final XMPPConnection conn, final Map<Long,Message> sentMessages) {
        
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
        synchronized (connections) {
            if (connections.containsKey(key)) {
                log.info("Using existing connection");
                return connections.get(key);
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
                            connections.remove(key);
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
            connections.put(key, future);
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
    
    private static String getMacAddress() throws SocketException {
        final Enumeration<NetworkInterface> nis = 
            NetworkInterface.getNetworkInterfaces();
        while (nis.hasMoreElements()) {
            final NetworkInterface ni = nis.nextElement();
            try {
                final byte[] mac = ni.getHardwareAddress();
                if (mac.length > 0) {
                    return Base64.encodeBase64String(mac);
                }
            } catch (final SocketException e) {
            }
        }
        try {
            return Base64.encodeBase64String(
                InetAddress.getLocalHost().getAddress()) + 
                System.currentTimeMillis();
        } catch (final UnknownHostException e) {
            final byte[] bytes = new byte[24];
            new Random().nextBytes(bytes);
            return Base64.encodeBase64String(bytes);
        }
    }
}
