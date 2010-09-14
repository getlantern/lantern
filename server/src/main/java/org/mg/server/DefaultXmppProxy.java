package org.mg.server;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.NetworkInterface;
import java.net.Socket;
import java.net.SocketException;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Enumeration;
import java.util.Properties;
import java.util.Queue;
import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;

import javax.net.SocketFactory;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
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
import org.jivesoftware.smack.packet.Packet;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smackx.ChatStateManager;
import org.littleshoot.proxy.Launcher;
import org.mg.common.Pair;
import org.mg.common.PairImpl;
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
        
        // We wait a second because the roster fetch sometimes fails.
        try {
            Thread.sleep(1000);
        } catch (final InterruptedException e2) {
            log.error("Exception during sleep?", e2);
        }
        while (!conn.isAuthenticated()) {
            log.info("Waiting for authentication");
            try {
                Thread.sleep(1000);
            } catch (final InterruptedException e1) {
                log.error("Exception during sleep?", e1);
            }
        }
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
                final Queue<Pair<Chat, XMPPConnection>> chats = 
                    addToGroup(chat, conn);
                
                final ConcurrentHashMap<String, ChannelFuture> proxyConnections =
                    new ConcurrentHashMap<String, ChannelFuture>();
                
                final String participant = chat.getParticipant();
                // We need to listen for the unavailability of clients we're 
                // chatting with so we can disconnect from their associated 
                // remote servers.
                final PacketListener pl = new PacketListener() {
                    public void processPacket(final Packet pack) {
                        if (!(pack instanceof Presence)) return;
                        final Presence pres = (Presence) pack;
                        final String from = pres.getFrom();
                        
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
                    new ChatMessageListener(proxyConnections, chats, 
                        MAC_ADDRESS, channelFactory);
                chat.addMessageListener(ml);
            }
        });
        return conn;
    }
    
    private Queue<Pair<Chat, XMPPConnection>> addToGroup(final Chat chat, 
        final XMPPConnection conn) {
        final String participant = chat.getParticipant();
        final String userAndMac = 
            StringUtils.substringBeforeLast(participant, "-");
        log.info("Parsed user and mac: {}", userAndMac);
        final Queue<Pair<Chat, XMPPConnection>> empty = 
            new LinkedBlockingQueue<Pair<Chat,XMPPConnection>>();
        final Queue<Pair<Chat, XMPPConnection>> existing = 
            userAndMacsToChats.putIfAbsent(userAndMac, empty);
        final Queue<Pair<Chat, XMPPConnection>> chats;
        if (existing == null) {
            chats = empty;
        }
        else {
            chats = existing;
        }
        chats.add(new PairImpl<Chat,XMPPConnection>(chat, conn));
        return chats;
    }
    
    private final ConcurrentHashMap<String, Queue<Pair<Chat, XMPPConnection>>> userAndMacsToChats =
        new ConcurrentHashMap<String, Queue<Pair<Chat, XMPPConnection>>>();
    

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
