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
import java.net.URISyntaxException;
import java.net.UnknownHostException;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.util.Arrays;
import java.util.Collection;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Properties;
import java.util.Queue;
import java.util.Random;
import java.util.Scanner;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;

import javax.net.SocketFactory;
import javax.net.ssl.SSLContext;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.ChatManager;
import org.jivesoftware.smack.MessageListener;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.SmackConfiguration;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Message;
import org.jivesoftware.smack.packet.Presence;
import org.lastbamboo.common.ice.IceMediaStreamDesc;
import org.lastbamboo.common.p2p.P2PConstants;
import org.lastbamboo.jni.JLibTorrent;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.p2p.P2P;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.proxy.NetworkUtils;
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
    
    private final String user;

    private final String pwd;

    final Map<String, HttpRequestHandler> hashCodesToHandlers =
        new ConcurrentHashMap<String, HttpRequestHandler>();
    
    final ConcurrentHashMap<Chat, Collection<String>> chatsToHashCodes =
        new ConcurrentHashMap<Chat, Collection<String>>();
    
    private final Set<InetSocketAddress> proxySet =
        new HashSet<InetSocketAddress>();
    private final Queue<InetSocketAddress> proxies = 
        new ConcurrentLinkedQueue<InetSocketAddress>();
    
    private final Set<URI> peerProxySet = new HashSet<URI>();
    private final Queue<URI> peerProxies = 
        new ConcurrentLinkedQueue<URI>();

    static {
        SmackConfiguration.setPacketReplyTimeout(30 * 1000);
    }
    
    private final XmppP2PClient client;

    private final MessageListener typedListener = new MessageListener() {
        public void processMessage(final Chat ch, final Message msg) {
            final String part = ch.getParticipant();
            if (part.startsWith("lanternxmpp@appspot.com")) {
                log.info("Lantern controlling agent response");
                final String body = msg.getBody();
                final Scanner scan = new Scanner(body);
                scan.useDelimiter(",");
                while (scan.hasNext()) {
                    final String ip = scan.next();
                    addProxy(ip, scan, ch);
                }
            }
            final Integer type = 
                (Integer) msg.getProperty(P2PConstants.MESSAGE_TYPE);
            if (type != null) {
                log.info("Processing typed message");
                processTypedMessage(msg, type, ch);
            } 
        }
    };
    
    private static final String ID = "-la-";

    private final KeyStoreManager keyStoreManager;

    private final int proxyPort;

    private Collection<String> trustedPeers = new HashSet<String>();
    
    /**
     * Creates a new pipeline factory with the specified class for processing
     * proxy authentication.
     * 
     * @param channelGroup The group that keeps track of open channels.
     */
    public HttpServerPipelineFactory(final ChannelGroup channelGroup,
        final KeyStoreManager keyStoreManager, final int proxyPort) {
        this.keyStoreManager = keyStoreManager;
        this.proxyPort = proxyPort;
        final Properties props = new Properties();
        final File propsDir = 
            new File(System.getProperty("user.home"), ".lantern");
        final File file = new File(propsDir, "lantern.properties");
        try {
            props.load(new FileInputStream(file));
            this.user = props.getProperty("google.user");
            this.pwd = props.getProperty("google.pwd");
            if (StringUtils.isBlank(this.user)) {
                log.error("No user name");
                throw new IllegalStateException("No user name in: " + file);
            }
            
            if (StringUtils.isBlank(this.pwd)) {
                log.error("No password.");
                throw new IllegalStateException("No password in: " + file);
            }
        } catch (final IOException e) {
            final String msg = "Error loading props file at: " + file;
            log.error(msg, e);
            throw new RuntimeException(msg, e);
        }
        
        final IceMediaStreamDesc streamDesc = 
            new IceMediaStreamDesc(true, false, "message", "http", 1, false);
        try {
            final String libName = System.mapLibraryName("jnltorrent");
            final JLibTorrent libTorrent = 
                new JLibTorrent(Arrays.asList(new File (new File(".."), 
                    libName), new File (libName)), true);
            
            final SocketFactory socketFactory = newTlsSocketFactory();
            
            this.client = P2P.newXmppP2PClient(streamDesc, "shoot", libTorrent, 
                libTorrent, new InetSocketAddress("127.0.0.1", this.proxyPort), 
                socketFactory);

            // This is a glabal, backup listener added to the client. We might
            // get notifications of messages twice in some cases, but that's
            // better than the alternative of sometimes not being notified
            // at all.
            this.client.addMessageListener(typedListener);
            this.client.login(this.user, this.pwd, ID);
            configureRoster();
        } catch (final IOException e) {
            final String msg = "Could not log in!!";
            log.warn(msg, e);
            throw new Error(msg, e);
        } catch (final XMPPException e) {
            final String msg = "Could not configure roster!!";
            log.warn(msg, e);
            throw new Error(msg, e);
        }
    }

    private SocketFactory newTlsSocketFactory() {
        log.info("Creating TLS socket factory");
        try {
            final SSLContext clientContext = SSLContext.getInstance("TLS");
            clientContext.init(null, this.keyStoreManager.getTrustManagers(), 
                null);
            return clientContext.getSocketFactory();
        } catch (final NoSuchAlgorithmException e) {
            log.error("No TLS?", e);
            throw new Error("No TLS?", e);
        } catch (final KeyManagementException e) {
            log.error("Key managmement issue?", e);
            throw new Error("Key managmement issue?", e);
        }
    }

    public ChannelPipeline getPipeline() {
        log.info("Getting pipeline...");
        // We randomly use peers and centralized proxies.
        synchronized (peerProxySet) {
            if (usePeerProxies()) {
                return peerProxy();
            }
        }
        synchronized (proxySet) {
            return centralizedProxy();
        }
    }
    
    private ChannelPipeline peerProxy() {
        log.info("Using PEER proxy connection...");
        final URI uri = peerProxies.poll();
        peerProxies.add(uri);
        final SimpleChannelUpstreamHandler handler = 
            new PeerProxyRelayHandler(uri, this, client);
        final ChannelPipeline pipeline = pipeline();
        pipeline.addLast("handler", handler);
        return pipeline;
    }

    private ChannelPipeline centralizedProxy() {
        log.info("Using DIRECT proxy connection...");
        // We just use it as a cyclic queue.
        if (proxies.isEmpty()) {
            log.info("No centralized proxies!!");
            return pipeline();
        }
        //final InetSocketAddress proxy = proxies.poll();
        final InetSocketAddress proxy = new InetSocketAddress("127.0.0.1", 8080);
        log.info("Using proxy: {}", proxy);
        //proxies.add(proxy);
        final SimpleChannelUpstreamHandler handler =
            new ProxyRelayHandler(proxy, this, this.keyStoreManager);
        final ChannelPipeline pipeline = pipeline();

        pipeline.addLast("handler", handler);
        return pipeline;
    }

    private boolean usePeerProxies() {
        if (peerProxySet != null) return true;
        if (peerProxySet.isEmpty()) {
            log.info("No peer proxies, so not using peers");
            return false;
        }
        if (proxySet.isEmpty()) {
            log.info("Using peer proxies since there are no centralized ones");
            return true;
        }
        final double rand = Math.random();
        if (rand > 0.25) {
            log.info("Using peer proxies - random was "+rand);
            return true;
        }
        log.info("Not using peer proxies -- random was "+rand);
        return false;
    }

    private void configureRoster() throws XMPPException {
        final XMPPConnection xmpp = this.client.getXmppConnection();
        
        
        final Roster roster = xmpp.getRoster();
        // Make sure we look for MG packets.
        //roster.createEntry("mglittleshoot@gmail.com", "MG", null);
        //roster.createEntry("bravenewsoftware@appspot.com", "MG", null);
        roster.createEntry("lanternxmpp@appspot.com", "Lantern", null);
        
        roster.addRosterListener(new RosterListener() {
            public void entriesDeleted(final Collection<String> addresses) {
                log.info("Entries deleted");
            }
            public void entriesUpdated(final Collection<String> addresses) {
                log.info("Entries updated: {}", addresses);
            }
            public void presenceChanged(final Presence presence) {
                processPresence(presence, xmpp);
            }
            public void entriesAdded(final Collection<String> addresses) {
                log.info("Entries added: "+addresses);
            }
        });
        
        // Now we add all the existing entries to get people who are already
        // online.
        final Collection<RosterEntry> entries = roster.getEntries();
        for (final RosterEntry entry : entries) {
            //log.info("Got entry: {}", entry);
            final String jid = entry.getUser();
            //log.info("Roster entry user: {}",jid);
            final Iterator<Presence> presences = 
                roster.getPresences(entry.getUser());
            while (presences.hasNext()) {
                final Presence p = presences.next();
                processPresence(p, xmpp);
            }
        }
        
        log.info("Finished adding listeners");
    }

    private void processPresence(final Presence p, final XMPPConnection xmpp) {
        final String from = p.getFrom();
        //log.info("Got presence with from: {}", from);
        if (isLanternHub(from)) {
            log.info("Got lantern proxy!!");
            final ChatManager chatManager = xmpp.getChatManager();
            final Chat chat = chatManager.createChat(from, typedListener);
            
            // Send an "info" message to gather proxy data.
            final Message msg = new Message();
            msg.setBody("/info");
            try {
                log.info("Sending info message to Lantern Hub");
                chat.sendMessage(msg);
            } catch (final XMPPException e) {
                log.error("Could not send INFO message", e);
            }
        }
        else if (isLanternJid(from)) {
            this.trustedPeers.add(from);
            addOrRemovePeer(p, from, xmpp);
        }
    }

    private void addOrRemovePeer(final Presence p, final String from, 
        final XMPPConnection xmpp) {
        final URI uri;
        try {
            uri = new URI(from);
        } catch (final URISyntaxException e) {
            log.error("Could not create URI from: {}", from);
            return;
        }
        if (p.isAvailable()) {
            log.info("Adding from to peer JIDs: {}", from);
            final Message msg = new Message();
            msg.setProperty(P2PConstants.MESSAGE_TYPE, 
                XmppMessageConstants.INFO_REQUEST_TYPE);
            
            // Set our certificate in the request as well -- we wan't to make
            // extra sure these get through!
            msg.setProperty(P2PConstants.CERT,
                this.keyStoreManager.getBase64Cert());
            final ChatManager cm = xmpp.getChatManager();
            final Chat chat = cm.createChat(from, typedListener);
            try {
                log.info("Sending INFO request to: {}", from);
                chat.sendMessage(msg);
            } catch (final XMPPException e) {
                log.info("Could not send message to peer", e); 
            }
        }
        else {
            log.info("Removing JID for peer '"+from+"' with presence: {}", p);
            removePeerUri(uri);
        }
    }

    private boolean isLanternHub(final String from) {
        //return from.startsWith("mglittleshoot");
        return from.startsWith("lanternxmpp@appspot.com");
    }

    private void sendErrorMessage(final Chat chat, final InetSocketAddress isa,
        final String message) {
        final Message msg = new Message();
        msg.setProperty(P2PConstants.MESSAGE_TYPE, 
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
        final String from = chat.getParticipant();
        log.info("Processing typed message from {}", from);
        if (!this.trustedPeers.contains(from)) {
            log.warn("Ignoring message from untrusted peer: {}", from);
            log.warn("Peer not in: {}", this.trustedPeers);
            return;
        }
        switch (type) {
            case (XmppMessageConstants.INFO_REQUEST_TYPE):
                log.info("Handling INFO request from {}", from);
                processInfoData(msg, chat);
                sendInfoResponse(chat);
                break;
            case (XmppMessageConstants.INFO_RESPONSE_TYPE):
                log.info("Handling INFO response from {}", from);
                processInfoData(msg, chat);
                break;
            default:
                log.warn("Did not understand type: "+type);
                break;
        }
    }
    
    private void processInfoData(final Message msg, final Chat chat) {
        log.info("Processing INFO data from request or response.");
        final String proxyString = 
            (String) msg.getProperty(XmppMessageConstants.PROXIES);
        if (StringUtils.isNotBlank(proxyString)) {
            log.info("Got proxies: {}", proxyString);
            final Scanner scan = new Scanner(proxyString);
            while (scan.hasNext()) {
                final String cur = scan.next();
                addProxy(cur, scan, chat);
            }
        }
        
        final String base64Cert =
            (String) msg.getProperty(P2PConstants.CERT);
        log.info("Base 64 cert: {}", base64Cert);
        if (StringUtils.isNotBlank(base64Cert)) {
            log.info("Got certificate:\n"+
                new String(Base64.decodeBase64(base64Cert)));
            // First we need to add this certificate to the trusted 
            // certificates on the proxy. Then we can add it to our list of
            // peers.
            final URI uri;
            try {
                uri = new URI(chat.getParticipant());
            } catch (final URISyntaxException e) {
                log.error("Could not create URI from: {}", 
                    chat.getParticipant());
                return;
            }
            try {
                // Add the peer if we're able to add the cert.
                this.keyStoreManager.addBase64Cert(uri, base64Cert);
                synchronized (peerProxySet) {
                    if (!peerProxySet.contains(uri)) {
                        peerProxies.add(uri);
                        peerProxySet.add(uri);
                    }
                }
            } catch (final IOException e) {
                log.error("Could not add cert??", e);
            }
        }
    }

    private void addProxy(final String cur, final Scanner scan, 
        final Chat chat) {
        log.info("Adding proxy: {}", cur);
        final String hostname = 
            StringUtils.substringBefore(cur, ":");
        final int port = 
            Integer.parseInt(StringUtils.substringAfter(cur, ":"));
        final InetSocketAddress isa = 
            new InetSocketAddress(hostname, port);
        if (proxySet.contains(isa)) {
            log.info("We already know about this proxy");
            return;
        }
        
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

    private void sendInfoResponse(final Chat ch) {
        final Message msg = new Message();
        msg.setProperty(P2PConstants.MESSAGE_TYPE, 
            XmppMessageConstants.INFO_RESPONSE_TYPE);
        
        // We want to separate out direct friend proxies here from the
        // proxies that are friends of friends. We only want to notify our
        // friends of other direct friend proxies, not friends of friends.
        msg.setProperty(XmppMessageConstants.PROXIES, "");
        msg.setProperty(P2PConstants.CERT,this.keyStoreManager.getBase64Cert());
        try {
            ch.sendMessage(msg);
        } catch (final XMPPException e) {
            log.error("Could not send info message", e);
        }
    }

    protected boolean isLanternJid(final String from) {
        // Here's the format we're looking for: "-la-"
        if (from.contains("/"+ID)) {
            log.info("Returning Lantern TRUE for from: {}", from);
            return true;
        }
        return false;
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
    }

    public void onCouldNotConnectToPeer(final URI peerUri) {
        removePeerUri(peerUri);
    }

    public void onError(final URI peerUri) {
        removePeerUri(peerUri);
    }

    private void removePeerUri(final URI peerUri) {
        log.info("Removing peer with URI: {}", peerUri);
        synchronized (this.peerProxySet) {
            this.peerProxySet.remove(peerUri);
            this.peerProxies.remove(peerUri);
        }
    }
}
