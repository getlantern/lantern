package org.mg.client;


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
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.Random;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;

import javax.net.SocketFactory;

import org.apache.commons.codec.binary.Base64;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.ChatManager;
import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.ConnectionListener;
import org.jivesoftware.smack.MessageListener;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.SmackConfiguration;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Message;
import org.jivesoftware.smack.packet.Presence;
import org.mg.common.MessagePropertyKeys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Factory for creating pipelines for incoming requests to our listening
 * socket.
 */
public class HttpServerPipelineFactory implements ChannelPipelineFactory {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final ChannelGroup channelGroup;
    
    private final String user;

    private final String pwd;

    private final String macAddress;
    
    private volatile int connectionsToFetch = 0;
    
    private static final int NUM_CONNECTIONS = 10;
    
    private final List<Chat> chats = new ArrayList<Chat>(NUM_CONNECTIONS);
    
    final Map<String, HttpRequestHandler> hashCodesToHandlers =
        new ConcurrentHashMap<String, HttpRequestHandler>();
    
    final ConcurrentHashMap<Chat, Collection<String>> chatsToHashCodes =
        new ConcurrentHashMap<Chat, Collection<String>>();
    
    private final Timer timer = new Timer("XMPP-Reconnect-Timer", true);
    
    static {
        SmackConfiguration.setPacketReplyTimeout(30 * 1000);
    }
    
    private final Collection<String> serverSideJids = new HashSet<String>();
    
    /**
     * Separate thread for creating new XMPP connections.
     */
    private final ExecutorService connector = 
        Executors.newCachedThreadPool(new ThreadFactory() {
            public Thread newThread(final Runnable r) {
                final Thread t = new Thread(r, "XMPP-Connector-Thread");
                t.setDaemon(true);
                return t;
            }
        });
    
    /**
     * Creates a new pipeline factory with the specified class for processing
     * proxy authentication.
     * 
     * @param authorizationManager The manager for proxy authentication.
     * @param channelGroup The group that keeps track of open channels.
     * @param filters HTTP filters to apply.
     */
    public HttpServerPipelineFactory(final ChannelGroup channelGroup) {
        this.channelGroup = channelGroup;
        final Properties props = new Properties();
        final File propsDir = new File(System.getProperty("user.home"), ".mg");
        final File file = new File(propsDir, "mg.properties");
        try {
            props.load(new FileInputStream(file));
            this.user = props.getProperty("google.user");
            this.pwd = props.getProperty("google.pwd");
            
            final Enumeration<NetworkInterface> ints = 
                NetworkInterface.getNetworkInterfaces();
            this.macAddress = getMacAddress(ints);
        } catch (final IOException e) {
            final String msg = "Error loading props file at: " + file;
            log.error(msg);
            throw new RuntimeException(msg, e);
        }
        
        persistentMonitoringConnection();
        
        for (int i = 0; i < NUM_CONNECTIONS; i++) {
            threadedXmppConnection();
        }
    }

    private void persistentXmppConnection() {
        for (int i = 0; i < 10; i++) {
            try {
                log.info("Attempting XMPP connection...");
                newXmppConnection();
                if (connectionsToFetch > 0) {
                    connectionsToFetch--;
                }
                log.info("Successfully connected...");
                return;
            } catch (final XMPPException e) {
                final String msg = "Error creating XMPP connection";
                log.error(msg, e);
            }
        }
    }

    public ChannelPipeline getPipeline() throws Exception {
        log.info("Getting pipeline...waiting for connection");
        
        final Chat chat = getChat();
        final ChannelPipeline pipeline = pipeline();
        final HttpRequestHandler handler = 
            new HttpRequestHandler(this.channelGroup, this.macAddress, chat);
        pipeline.addLast("handler", handler);
        
        final String hc = String.valueOf(handler.hashCode());
        this.hashCodesToHandlers.put(hc, handler);
        
        final Collection<String> list = chatsToHashCodes.get(chat);
        
        // Could be some race conditions, so check for null.
        if (list != null) {
            list.add(hc);
        }
        
        return pipeline;
    }

    private Chat getChat() {
        synchronized (this.chats) {
            while (chats.isEmpty()) {
                log.info("Waiting for chats...");
                try {
                    chats.wait(10000);
                } catch (InterruptedException e) {
                }
            }
            Collections.shuffle(chats);
            return chats.get(0);
        }
    }

    private void threadedXmppConnection() {
        connector.submit(new Runnable() {
            public void run() {
                persistentXmppConnection();
            }
        });
    }

    private void delayedXmppConnection() {
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                threadedXmppConnection();
            }
            
        }, 5 * 1000);
    }

    private void newXmppConnection() throws XMPPException {
        final ConnectionConfiguration config = 
            new ConnectionConfiguration("talk.google.com", 5222, "gmail.com");
        config.setCompressionEnabled(true);
        config.setReconnectionAllowed(false);
        config.setSocketFactory(new SocketFactory() {
            
            @Override
            public Socket createSocket(InetAddress arg0, int arg1, InetAddress arg2,
                    int arg3) throws IOException {
                // TODO Auto-generated method stub
                return null;
            }
            
            @Override
            public Socket createSocket(String arg0, int arg1, InetAddress arg2, int arg3)
                    throws IOException, UnknownHostException {
                // TODO Auto-generated method stub
                return null;
            }
            
            @Override
            public Socket createSocket(InetAddress arg0, int arg1) throws IOException {
                // TODO Auto-generated method stub
                return null;
            }
            
            @Override
            public Socket createSocket(final String host, final int port) 
                throws IOException, UnknownHostException {
                log.info("Creating socket");
                final Socket sock = new Socket();
                sock.connect(new InetSocketAddress(host, port), 50 * 1000);
                log.info("Socket connected");
                return sock;
            }
        });
        
        final XMPPConnection xmpp = new XMPPConnection(config);
        xmpp.connect();
        xmpp.login(this.user, this.pwd, "MG");
        
        synchronized (serverSideJids) {
            while (serverSideJids.size() < 4) {
                log.info("Waiting for JIDs of MG servers...");
                try {
                    serverSideJids.wait(10000);
                } catch (final InterruptedException e) {
                    log.error("Interruped?", e);
                }
            }
        }
        
        final List<String> strs;
        synchronized (serverSideJids) {
            strs = new ArrayList<String>(serverSideJids);
        }
        
        Collections.shuffle(strs);
        final String jid = strs.iterator().next();

        final ChatManager chatManager = xmpp.getChatManager();
        final Chat chat = chatManager.createChat(jid,
            new MessageListener() {
            
                public void processMessage(final Chat ch, final Message msg) {
                    final String hashCode = 
                        (String) msg.getProperty(MessagePropertyKeys.HASHCODE);
                    final HttpRequestHandler handler = 
                        hashCodesToHandlers.get(hashCode);
                    
                    if (handler == null) {
                        log.error("NO MATCHING HANDLER??");
                        return;
                    }
                    log.info("Sending message to handler...");
                    handler.processMessage(ch, msg);
                }
            });
        
        xmpp.addConnectionListener(new ConnectionListener() {
            
            public void reconnectionSuccessful() {
                log.info("Reconnection successful...");
            }
            
            public void reconnectionFailed(final Exception e) {
                log.info("Reconnection failed", e);
            }
            
            public void reconnectingIn(final int time) {
                log.info("Reconnecting to XMPP server in "+time);
            }
            
            public void connectionClosedOnError(final Exception e) {
                log.info("XMPP connection closed on error", e);
            }
            
            public void connectionClosed() {
                log.info("XMPP connection closed...removing chat");
                //connectionsToFetch++;
                chats.remove(chat);
                final Collection<String> codes = chatsToHashCodes.remove(chat);
                for (final String code : codes) {
                    hashCodesToHandlers.remove(code);
                }
                delayedXmppConnection();
            }
        });
        
        this.chats.add(chat);
        this.chatsToHashCodes.put(chat, new ArrayList<String>());
    }
    
    private void persistentMonitoringConnection() {
        for (int i = 0; i < 10; i++) {
            try {
                log.info("Attempting XMPP MONITORING connection...");
                singleMonitoringConnection();
                log.info("Successfully connected...");
                return;
            } catch (final XMPPException e) {
                final String msg = "Error creating XMPP connection";
                log.error(msg, e);
            }
        }
    }

    private void singleMonitoringConnection() throws XMPPException {
        final ConnectionConfiguration config = 
            new ConnectionConfiguration("talk.google.com", 5222, "gmail.com");
        config.setCompressionEnabled(true);
        config.setRosterLoadedAtLogin(true);
        config.setReconnectionAllowed(false);
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
                sock.connect(new InetSocketAddress(host, port), 30000);
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
        
        final XMPPConnection xmpp = new XMPPConnection(config);
        xmpp.connect();
        xmpp.login(this.user, this.pwd, "MG");
        
        final Roster roster = xmpp.getRoster();
        
        
        roster.addRosterListener(new RosterListener() {
            public void entriesDeleted(Collection<String> addresses) {}
            public void entriesUpdated(Collection<String> addresses) {}
            public void presenceChanged(final Presence presence) {
                final String from = presence.getFrom();
                if (from.startsWith("mglittleshoot@gmail.com")) {
                    log.info("PACKET: "+presence);
                    log.info("Packet is from: {}", from);
                    if (presence.isAvailable()) {
                        serverSideJids.add(from);
                        synchronized (serverSideJids) {
                            serverSideJids.notifyAll();
                        }
                    }
                    else {
                        log.info("Removing connection with status {}", 
                            presence.getStatus());
                        serverSideJids.remove(from);
                    }
                }
            }
            public void entriesAdded(final Collection<String> addresses) {
                log.info("Entries added: "+addresses);
            }
        });

        // Make sure we look for MG packets.
        roster.createEntry("mglittleshoot@gmail.com", "MG", null);

        xmpp.addConnectionListener(new ConnectionListener() {
            
            public void reconnectionSuccessful() {
                log.info("Reconnection successful...");
            }
            
            public void reconnectionFailed(final Exception e) {
                log.info("Reconnection failed", e);
            }
            
            public void reconnectingIn(final int time) {
                log.info("Reconnecting to XMPP server in "+time);
            }
            
            public void connectionClosedOnError(final Exception e) {
                log.info("XMPP connection closed on error", e);
            }
            
            public void connectionClosed() {
                log.info("XMPP connection closed");
                persistentMonitoringConnection();
            }
        });
    }
    
    private String getMacAddress(final Enumeration<NetworkInterface> nis) {
        while (nis.hasMoreElements()) {
            final NetworkInterface ni = nis.nextElement();
            try {
                final byte[] mac = ni.getHardwareAddress();
                if (mac != null && mac.length > 0) {
                    log.info("Returning 'normal' MAC address");
                    return Base64.encodeBase64String(mac);
                }
            } catch (final SocketException e) {
                log.warn("Could not get MAC address?");
            }
        }
        try {
            log.warn("Returning custom MAC address");
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
