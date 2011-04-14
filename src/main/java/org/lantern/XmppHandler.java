package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.net.URISyntaxException;
import java.security.KeyManagementException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.Security;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateException;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Properties;
import java.util.Queue;
import java.util.Scanner;
import java.util.Set;
import java.util.concurrent.ConcurrentLinkedQueue;

import javax.net.ServerSocketFactory;
import javax.net.SocketFactory;
import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
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
import org.lastbamboo.common.p2p.P2PConstants;
import org.lastbamboo.jni.JLibTorrent;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.p2p.P2P;
import org.littleshoot.proxy.KeyStoreManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handles logging in to the XMPP server and processing trusted users through
 * the roster.
 */
public class XmppHandler implements ProxyStatusListener, ProxyProvider {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final String user;

    private final String pwd;
    
    private final Set<ProxyHolder> proxySet =
        new HashSet<ProxyHolder>();
    private final Queue<ProxyHolder> proxies = 
        new ConcurrentLinkedQueue<ProxyHolder>();
    
    private final Set<URI> peerProxySet = new HashSet<URI>();
    private final Queue<URI> peerProxies = 
        new ConcurrentLinkedQueue<URI>();
    
    private final Set<ProxyHolder> laeProxySet =
        new HashSet<ProxyHolder>();
    private final Queue<ProxyHolder> laeProxies = 
        new ConcurrentLinkedQueue<ProxyHolder>();

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

    private final int sslProxyRandomPort;

    private Collection<String> trustedPeers = new HashSet<String>();

    /**
     * Creates a new XMPP handler.
     * 
     * @param keyStoreManager The class for managing certificates.
     * @param sslProxyRandomPort The port of the HTTP proxy that other peers  
     * will relay to.
     * @param plainTextProxyRandomPort The port of the HTTP proxy running
     * only locally and accepting plain-text sockets.
     */
    public XmppHandler(final KeyStoreManager keyStoreManager, 
        final int sslProxyRandomPort, 
        final int plainTextProxyRandomPort) {
        this.keyStoreManager = keyStoreManager;
        this.sslProxyRandomPort = sslProxyRandomPort;
        final Properties props = new Properties();
        final File file = 
            new File(LanternUtils.configDir(), "lantern.properties");
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
        
        try {
            final String libName = System.mapLibraryName("jnltorrent");
            final JLibTorrent libTorrent = 
                new JLibTorrent(Arrays.asList(new File (new File(".."), 
                    libName), new File (libName)), true);
            
            final SocketFactory socketFactory = newTlsSocketFactory();
            final ServerSocketFactory serverSocketFactory =
                newTlsServerSocketFactory();
            
            final InetSocketAddress plainTextProxyRelayAddress = 
                new InetSocketAddress("127.0.0.1", plainTextProxyRandomPort);
            this.client = P2P.newXmppP2PHttpClient("shoot", libTorrent, 
                libTorrent, new InetSocketAddress(this.sslProxyRandomPort), 
                socketFactory, serverSocketFactory, plainTextProxyRelayAddress);

            // This is a global, backup listener added to the client. We might
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

    private ServerSocketFactory newTlsServerSocketFactory() {
        log.info("Creating TLS server socket factory");
        String algorithm = 
            Security.getProperty("ssl.KeyManagerFactory.algorithm");
        if (algorithm == null) {
            algorithm = "SunX509";
        }
        try {
            final KeyStore ks = KeyStore.getInstance("JKS");
            ks.load(this.keyStoreManager.keyStoreAsInputStream(),
                    this.keyStoreManager.getKeyStorePassword());

            // Set up key manager factory to use our key store
            final KeyManagerFactory kmf = KeyManagerFactory.getInstance(algorithm);
            kmf.init(ks, this.keyStoreManager.getCertificatePassword());

            // Initialize the SSLContext to work with our key managers.
            final SSLContext serverContext = SSLContext.getInstance("TLS");
            serverContext.init(kmf.getKeyManagers(), null, null);
            return serverContext.getServerSocketFactory();
        } catch (final KeyStoreException e) {
            throw new Error("Could not create SSL server socket factory.", e);
        } catch (final NoSuchAlgorithmException e) {
            throw new Error("Could not create SSL server socket factory.", e);
        } catch (final CertificateException e) {
            throw new Error("Could not create SSL server socket factory.", e);
        } catch (final IOException e) {
            throw new Error("Could not create SSL server socket factory.", e);
        } catch (final UnrecoverableKeyException e) {
            throw new Error("Could not create SSL server socket factory.", e);
        } catch (final KeyManagementException e) {
            throw new Error("Could not create SSL server socket factory.", e);
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

    private void configureRoster() throws XMPPException {
        final XMPPConnection xmpp = this.client.getXmppConnection();
        
        
        final Roster roster = xmpp.getRoster();
        // Make sure we look for Lantern packets.
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
            msg.setProperty(P2PConstants.MAC, LanternUtils.getMacAddress());
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
        
        final String mac =
            (String) msg.getProperty(P2PConstants.MAC);
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
                this.keyStoreManager.addBase64Cert(mac, base64Cert);
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
        if (cur.contains("appspot")) {
            addLaeProxy(cur, chat);
        } else {
            addGeneralProxy(cur, scan, chat);
        }
    }

    private void addLaeProxy(final String cur, final Chat chat) {
        log.info("Adding LAE proxy");
        addProxyWithChecks(this.laeProxySet, this.laeProxies, 
            new ProxyHolder(cur, new InetSocketAddress(cur, 443)), chat);
    }
    
    private void addGeneralProxy(final String cur, final Scanner scan,
        final Chat chat) {
        final String hostname = 
            StringUtils.substringBefore(cur, ":");
        final int port = 
            Integer.parseInt(StringUtils.substringAfter(cur, ":"));
        final InetSocketAddress isa = 
            new InetSocketAddress(hostname, port);
        addProxyWithChecks(proxySet, proxies, new ProxyHolder(hostname, isa), chat);
    }

    private void addProxyWithChecks(final Set<ProxyHolder> set,
        final Queue<ProxyHolder> queue, final ProxyHolder ph, 
        final Chat chat) {
        if (set.contains(ph)) {
            log.info("We already know about proxy "+ph+" in {}", set);
            return;
        }
        
        final Socket sock = new Socket();
        try {
            sock.connect(ph.isa, 60*1000);
            synchronized (set) {
                if (!set.contains(ph)) {
                    set.add(ph);
                    queue.add(ph);
                    log.info("Queue is now: {}", queue);
                }
            }
        } catch (final IOException e) {
            log.error("Could not connect to: {}", ph);
            sendErrorMessage(chat, ph.isa, e.getMessage());
            onCouldNotConnect(ph.isa);
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
        msg.setProperty(P2PConstants.MAC, LanternUtils.getMacAddress());
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

    
    public void onCouldNotConnect(final InetSocketAddress proxyAddress) {
        log.info("COULD NOT CONNECT!! Proxy address: {}", proxyAddress);
        onCouldNotConnect(new ProxyHolder(proxyAddress.getHostName(), proxyAddress), this.proxySet, this.proxies);
    }
    
    public void onCouldNotConnectToLae(final InetSocketAddress proxyAddress) {
        onCouldNotConnect(new ProxyHolder(proxyAddress.getHostName(), proxyAddress), this.laeProxySet, this.laeProxies);
    }
    
    public void onCouldNotConnect(final ProxyHolder proxyAddress,
        final Set<ProxyHolder> set, final Queue<ProxyHolder> queue){
        log.info("COULD NOT CONNECT!! Proxy address: {}", proxyAddress);
        synchronized (this.proxySet) {
            set.remove(proxyAddress);
            queue.remove(proxyAddress);
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

    public InetSocketAddress getLaeProxy() {
        return getProxy(this.laeProxySet, this.laeProxies);
    }
    
    public InetSocketAddress getProxy() {
        return getProxy(this.proxySet, this.proxies);
    }
    
    private InetSocketAddress getProxy(final Collection<ProxyHolder> set,
        final Queue<ProxyHolder> queue) {
        final ProxyHolder proxy = queue.remove();
        queue.add(proxy);
        log.info("FIFO queue is now: {}", queue);
        return proxy.isa;
    }

    private static final class ProxyHolder {
        
        private final String id;
        private final InetSocketAddress isa;

        private ProxyHolder(final String id, final InetSocketAddress isa) {
            this.id = id;
            this.isa = isa;
        }
        
        @Override
        public String toString() {
            return "ProxyHolder [isa=" + isa + "]";
        }
        
        @Override
        public int hashCode() {
            final int prime = 31;
            int result = 1;
            result = prime * result + ((id == null) ? 0 : id.hashCode());
            result = prime * result + ((isa == null) ? 0 : isa.hashCode());
            return result;
        }

        @Override
        public boolean equals(Object obj) {
            if (this == obj)
                return true;
            if (obj == null)
                return false;
            if (getClass() != obj.getClass())
                return false;
            ProxyHolder other = (ProxyHolder) obj;
            if (id == null) {
                if (other.id != null)
                    return false;
            } else if (!id.equals(other.id))
                return false;
            if (isa == null) {
                if (other.isa != null)
                    return false;
            } else if (!isa.equals(other.isa))
                return false;
            return true;
        }
    }
}
