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
import java.net.URI;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.Queue;
import java.util.Random;
import java.util.Scanner;
import java.util.Set;
import java.util.Timer;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.Executor;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.SmackConfiguration;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Message;
import org.jivesoftware.smack.packet.Presence;
import org.lastbamboo.common.ice.IceMediaStreamDesc;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.p2p.P2P;
import org.mg.common.LanternConstants;
import org.mg.common.XmppMessageConstants;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Factory for creating pipelines for incoming requests to our listening
 * socket.
 */
public class HttpServerPipelineFactory implements ChannelPipelineFactory, 
    ProxyStatusListener {
    
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
    
    private final Set<InetSocketAddress> proxySet =
        new HashSet<InetSocketAddress>();
    private final Queue<InetSocketAddress> proxies = 
        new ConcurrentLinkedQueue<InetSocketAddress>();
    
    private final Set<URI> peerProxySet = new HashSet<URI>();
    private final Queue<URI> peerProxies = new ConcurrentLinkedQueue<URI>();

    static {
        SmackConfiguration.setPacketReplyTimeout(30 * 1000);
    }
    
    private final Executor executor = Executors.newCachedThreadPool();
    
    private final ClientSocketChannelFactory clientSocketChannelFactory =
        new NioClientSocketChannelFactory(executor, executor);
    
    private final Collection<String> proxyJids = new HashSet<String>();
    
    private final Collection<String> peerProxyJids = new HashSet<String>();

    private final XmppP2PClient client;
    
    private static final String ID = "-la-";
    
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
            log.error(msg, e);
            throw new RuntimeException(msg, e);
        }
        
        //persistentMonitoringConnection();
        
        final IceMediaStreamDesc streamDesc = 
            new IceMediaStreamDesc(true, true, "message", "http", 1, false);
        try {
            this.client = P2P.newXmppP2PClient(streamDesc, 
                LanternConstants.LANTERN_PROXY_PORT);
            this.client.login(this.user, this.pwd, ID);
            addRosterListener();
        } catch (final IOException e) {
            final String msg = "Could not log in!!";
            log.warn(msg, e);
            throw new RuntimeException(msg, e);
        } catch (final XMPPException e) {
            final String msg = "Could not configure roster!!";
            log.warn(msg, e);
            throw new RuntimeException(msg, e);
        }
    }

    public ChannelPipeline getPipeline() {
        log.info("Getting pipeline...");
        
        final ChannelPipeline pipeline = pipeline();
        
        // TODO: We should make sure to mix up all the proxies, sometimes
        // using peers, sometimes using centralized.
        
        synchronized (peerProxySet) {
            if (!peerProxySet.isEmpty()) {
                log.info("Using PEER proxy connection...");
                final URI proxy = peerProxies.poll();
                peerProxies.add(proxy);
                final SimpleChannelUpstreamHandler handler = 
                    new PeerProxyRelayHandler(proxy, this, this.client);
                pipeline.addLast("handler", handler);
                return pipeline;
            }
            else {
                log.info("No peer proxies!!");
            }
        }
        
        synchronized (proxySet) {
            if (!proxySet.isEmpty()) {
                log.info("Using DIRECT proxy connection...");
                // We just use it as a cyclic queue.
                final InetSocketAddress proxy = proxies.poll();
                proxies.add(proxy);
                final SimpleChannelUpstreamHandler handler = 
                    new ProxyRelayHandler(proxy,clientSocketChannelFactory,this);
                pipeline.addLast("handler", handler);
                return pipeline;
            }
        }
        
        /*
        log.info("Using XMPP relays...");
        final Chat chat = getChat();
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
        */
        return pipeline;
    }
    
    private void addRosterListener() throws XMPPException {
        final XMPPConnection xmpp = this.client.getXmppConnection();
        final Roster roster = xmpp.getRoster();
        
        roster.addRosterListener(new RosterListener() {
            public void entriesDeleted(final Collection<String> addresses) {
                log.info("Entries deleted");
            }
            public void entriesUpdated(final Collection<String> addresses) {
                log.info("Entries updated: {}", addresses);
            }
            public void presenceChanged(final Presence presence) {
                final String from = presence.getFrom();
                if (from.startsWith("mglittleshoot@gmail.com")) {
                    processPresenceChanged(presence, from, xmpp, proxyJids);
                }
                else if (isMg(from)) {
                    // We've received a changed presence state for an MG peer.
                    processPresenceChanged(presence, from, xmpp, peerProxyJids);
                }
            }
            public void entriesAdded(final Collection<String> addresses) {
                log.info("Entries added: "+addresses);
            }
        });

        // Make sure we look for MG packets.
        roster.createEntry("mglittleshoot@gmail.com", "MG", null);
        log.info("Finished adding listeners");
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

    
    private void sendErrorMessage(final Chat chat, final InetSocketAddress isa,
        final String message) {
        final Message msg = new Message();
        msg.setProperty(XmppMessageConstants.TYPE, 
            XmppMessageConstants.ERROR_TYPE);
        final String errorMessage = "Error: "+message+" with host: "+isa;
        msg.setProperty(XmppMessageConstants.MESSAGE, errorMessage);
        try {
            chat.sendMessage(msg);
        } catch (final XMPPException e) {
            log.error("Error sending message", e);
        }
    }
    
    private void processTypedMessage(final Message msg, final Integer type, 
        final Chat chat) {
        switch (type) {
            case (XmppMessageConstants.INFO_REQUEST_TYPE):
                sendInfoResponse(chat);
                break;
            case (XmppMessageConstants.INFO_RESPONSE_TYPE):
                processInfoResponse(msg, chat);
                
                break;
            default:
                break;
        }
    }
    
    private void processInfoResponse(final Message msg, final Chat chat) {
        final String proxyString = 
            (String) msg.getProperty(XmppMessageConstants.PROXIES);
        log.info("Got proxies: {}", proxyString);
        final Scanner scan = new Scanner(proxyString);
        while (scan.hasNext()) {
            final String cur = scan.next();
            final String hostname = 
                StringUtils.substringBefore(cur, ":");
            final int port = 
                Integer.parseInt(StringUtils.substringAfter(cur, ":"));
            final InetSocketAddress isa = 
                new InetSocketAddress(hostname, port);
            
            final Socket sock = new Socket();
            try {
                sock.connect(isa, 60*1000);
                synchronized (proxySet) {
                    if (!proxySet.contains(isa)) {
                        proxySet.add(isa);
                        proxies.add(isa);
                    }
                }
            } catch (final IOException e) {
                log.error("Could not connect to: {}", isa);
                sendErrorMessage(chat, isa, e.getMessage());
                
                // If we don't have any more proxies to connect to,
                // revert to XMPP relay mode.
                if (!scan.hasNext()) {
                    onCouldNotConnect(isa);
                }
            } finally {
                try {
                    sock.close();
                } catch (final IOException e) {
                    log.info("Exception closing", e);
                }
            }
        }
    }

    private void sendInfoResponse(final Chat ch) {
        final Message msg = new Message();
        msg.setProperty(XmppMessageConstants.TYPE, 
            XmppMessageConstants.INFO_RESPONSE_TYPE);
        //final InetAddress address = AmazonEc2Utils.getPublicAddress();
        //final String proxies = 
        //    address.getHostAddress() + ":"+;
        
        // We want to separate out direct friend proxies here from the
        // proxies that are friends of friends. We only want to notify our
        // friends of other direct friend proxies, not friends of friends.
        msg.setProperty(XmppMessageConstants.PROXIES, "");
        try {
            ch.sendMessage(msg);
        } catch (final XMPPException e) {
            log.error("Could not send info message", e);
        }
    }

    protected boolean isMg(final String from) {
        // Here's the format we're looking for: 
        // "-mg-"
        // final String id = "-"+macAddress+"-";
        //if (from.endsWith("-") && from.contains("/-")) {
        if (from.contains(ID)) {
            log.info("Returning MG TRUE for from: {}", from);
            return true;
        }
        log.info("Returning MG FALSE for from: {}", from);
        return false;
    }

    protected void processPresenceChanged(final Presence presence, 
        final String from, final XMPPConnection xmpp, 
        final Collection<String> jids) {
        log.info("PACKET: "+presence);
        log.info("Packet is from: {}", from);
        if (presence.isAvailable()) {
            /*
            final ChatManager chatManager = xmpp.getChatManager();
            final Chat chat = chatManager.createChat(from,
                new MessageListener() {
                
                    public void processMessage(final Chat ch, 
                        final Message msg) {
                        final Integer type = 
                            (Integer) msg.getProperty(XmppMessageConstants.TYPE);
                        if (type != null) {
                            processTypedMessage(msg, type, ch);
                            return;
                        }
                    }
                });
            
            
            // Send an "info" message to gather proxy data.
            final Message msg = new Message();
            msg.setProperty(XmppMessageConstants.TYPE, 
                XmppMessageConstants.INFO_REQUEST_TYPE);
            try {
                chat.sendMessage(msg);
            } catch (final XMPPException e) {
                log.error("Could not send INFO message", e);
            }
            */
            jids.add(from);
            synchronized (jids) {
                jids.notifyAll();
            }
        }
        else {
            log.info("Removing connection with status {}", 
                presence.getStatus());
            jids.remove(from);
        }
    }

    private String getMacAddress(final Enumeration<NetworkInterface> nis) {
        while (nis.hasMoreElements()) {
            final NetworkInterface ni = nis.nextElement();
            try {
                final byte[] mac = ni.getHardwareAddress();
                if (mac != null && mac.length > 0) {
                    log.info("Returning 'normal' MAC address");
                    return Base64.encodeBase64String(mac).trim();
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

    public void onCouldNotConnect(final InetSocketAddress proxyAddress) {
        log.info("COULD NOT CONNECT!! Proxy address: {}", proxyAddress);
        synchronized (this.proxySet) {
            this.proxySet.remove(proxyAddress);
            this.proxies.remove(proxyAddress);
        }
        /*
        if (this.proxySet.isEmpty()) {
            for (int i = 0; i < NUM_CONNECTIONS; i++) {
                threadedXmppConnection();
            }
        }
        */
    }

    public void onCouldNotConnectToPeer(final URI peerUri) {
        synchronized (this.peerProxySet) {
            this.peerProxySet.remove(peerUri);
            this.peerProxies.remove(peerUri);
        }
    }
    

    /*
    private void threadedXmppConnection() {
        connector.submit(new Runnable() {
            public void run() {
                persistentXmppConnection();
            }
        });
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
        final String id = "-"+macAddress+"-";
        log.info("Chat ID: "+id);
        xmpp.login(this.user, this.pwd, id);
        while (!xmpp.isAuthenticated()) {
            log.info("Waiting for authentication");
            try {
                Thread.sleep(1000);
            } catch (final InterruptedException e1) {
                log.error("Exception during sleep?", e1);
            }
        }
        
        synchronized (proxyJids) {
            while (proxyJids.size() < 4) {
                log.info("Waiting for JIDs of MG servers...");
                try {
                    proxyJids.wait(10000);
                } catch (final InterruptedException e) {
                    log.error("Interruped?", e);
                }
            }
        }
        
        final List<String> strs;
        synchronized (proxyJids) {
            strs = new ArrayList<String>(proxyJids);
        }
        
        Collections.shuffle(strs);
        final String jid = strs.iterator().next();

        final ChatManager chatManager = xmpp.getChatManager();
        final Chat chat = chatManager.createChat(jid,
            new MessageListener() {
            
                public void processMessage(final Chat ch, final Message msg) {
                    final Integer type = 
                        (Integer) msg.getProperty(XmppMessageConstants.TYPE);
                    if (type != null) {
                        processTypedMessage(msg, type, ch);
                        return;
                    }
                    final String hashCode = 
                        (String) msg.getProperty(XmppMessageConstants.HASHCODE);
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
    */
    
    

    /*
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
                final int localPort) throws IOException, UnknownHostException {
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
        
        final XMPPConnection xmpp = new XMPPConnection(config);
        xmpp.connect();
        
        // We have a limited number of bytes to work with here, so we just
        // append the MAC straight after the "MG".
        final String id = "MG"+macAddress;
        xmpp.login(this.user, this.pwd, id);
        
        while (!xmpp.isAuthenticated()) {
            log.info("Waiting for authentication");
            try {
                Thread.sleep(1000);
            } catch (final InterruptedException e1) {
                log.error("Exception during sleep?", e1);
            }
        }
        
        final Roster roster = xmpp.getRoster();
        
        roster.addRosterListener(new RosterListener() {
            public void entriesDeleted(Collection<String> addresses) {}
            public void entriesUpdated(Collection<String> addresses) {}
            public void presenceChanged(final Presence presence) {
                final String from = presence.getFrom();
                if (from.startsWith("mglittleshoot@gmail.com")) {
                    processPresenceChanged(presence, from, xmpp, proxyJids);
                }
                else if (isMg(from)) {
                    // We've received a changed presence state for an MG peer.
                    processPresenceChanged(presence, from, xmpp, peerProxyJids);
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
                log.info("XMPP connection closed. Creating new connection.");
                persistentMonitoringConnection();
            }
        });
    }
    */
}
