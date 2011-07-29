package org.lantern;

import java.io.File;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Queue;
import java.util.Scanner;
import java.util.Set;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;

import javax.net.ServerSocketFactory;
import javax.net.SocketFactory;

import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.ChatManager;
import org.jivesoftware.smack.MessageListener;
import org.jivesoftware.smack.PacketListener;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.SmackConfiguration;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.filter.PacketFilter;
import org.jivesoftware.smack.packet.Message;
import org.jivesoftware.smack.packet.Packet;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smack.provider.ProviderManager;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.lantern.xmpp.GenericIQProvider;
import org.lastbamboo.common.p2p.P2PConstants;
import org.lastbamboo.jni.JLibTorrent;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.littleshoot.p2p.P2P;
import org.littleshoot.util.CommonUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handles logging in to the XMPP server and processing trusted users through
 * the roster.
 */
public class XmppHandler implements ProxyStatusListener, ProxyProvider {
    
    //private static final String LANTERN_JID = "lanternxmpp@appspot.com";
    private static final String LANTERN_JID = "lantern-controller@appspot.com";

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final String email;

    private final String pwd;
    
    private final Set<ProxyHolder> proxySet =
        new HashSet<ProxyHolder>();
    private final Queue<ProxyHolder> proxies = 
        new ConcurrentLinkedQueue<ProxyHolder>();
    
    private final Set<URI> peerProxySet = new HashSet<URI>();
    private final Queue<URI> peerProxies = 
        new ConcurrentLinkedQueue<URI>();
    
    private final Set<URI> anonymousProxySet = new HashSet<URI>();
    private final Queue<URI> anonymousProxies = 
        new ConcurrentLinkedQueue<URI>();
    
    private final Set<ProxyHolder> laeProxySet =
        new HashSet<ProxyHolder>();
    private final Queue<ProxyHolder> laeProxies = 
        new ConcurrentLinkedQueue<ProxyHolder>();

    static {
        SmackConfiguration.setPacketReplyTimeout(30 * 1000);
    }
    
    private final XmppP2PClient client;
    private boolean displayedUpdateMessage = false;
    

    private final MessageListener typedListener = new MessageListener() {

        @Override
        public void processMessage(final Chat ch, final Message msg) {
            final String part = ch.getParticipant();
            log.info("Got chat participant: {} with message:\n {}", part, 
                msg.toXML());
            if (part.startsWith(LANTERN_JID)) {
                log.info("Lantern controlling agent response");
                final String body = msg.getBody();
                log.info("Body: {}", body);
                final Object obj = JSONValue.parse(body);
                final JSONObject json = (JSONObject) obj;
                final JSONArray servers = 
                    (JSONArray) json.get(LanternConstants.SERVERS);
                final Long delay = 
                    (Long) json.get(LanternConstants.UPDATE_TIME);
                if (delay != null) {
                    final long now = System.currentTimeMillis();
                    final long elapsed = now - lastInfoMessageScheduled;
                    if (elapsed < 10000) {
                        log.info("Ignoring duplicate info request scheduling- "+
                            "scheduled request {} milliseconds ago.", elapsed);
                        return;
                    }
                    lastInfoMessageScheduled = now;
                    updateTimer.schedule(new TimerTask() {
                        @Override
                        public void run() {
                            sendInfoRequest();
                        }
                    }, delay);
                    log.info("Scheduled next info request in {} milliseconds", 
                        delay);
                }
                
                if (servers == null) {
                    log.info("XMPP: "+XmppUtils.toString(msg));
                } else {
                    final Iterator<String> iter = servers.iterator();
                    while (iter.hasNext()) {
                        final String server = iter.next();
                        addProxy(server, ch);
                    }
                    if (!servers.isEmpty() && ! Configurator.configured()) {
                        Configurator.configure();
                        tray.activate();
                    }
                }
                
                // This is really a JSONObject, but that itself is a map.
                final Map<String, String> update = 
                    (Map<String, String>) json.get(LanternConstants.UPDATE_KEY);
                log.info("Already displayed update? {}", displayedUpdateMessage);
                if (update != null && !displayedUpdateMessage) {
                    log.info("About to show update...");
                    displayedUpdateMessage = true;
                    LanternHub.display().asyncExec (new Runnable () {
                        @Override
                        public void run () {
                            LanternHub.systemTray().addUpdate(update);
                            //final LanternBrowser lb = new LanternBrowser(true);
                            //lb.showUpdate(update);
                        }
                    });
                }
            }
            final Integer type = 
                (Integer) msg.getProperty(P2PConstants.MESSAGE_TYPE);
            if (type != null) {
                log.info("Not processing typed message");
                //processTypedMessage(msg, type, ch);
            } 
        }
    };
    
    private static final String ID = "-la-";

    private final int sslProxyRandomPort;


    //private String hubAddress = "";
    
    private final Timer updateTimer = new Timer(true);

    private Chat hubChat;

    private final SystemTray tray;

    private volatile long lastInfoMessageScheduled = 0L;

    /**
     * Creates a new XMPP handler.
     * 
     * @param keyStoreManager The class for managing certificates.
     * @param sslProxyRandomPort The port of the HTTP proxy that other peers  
     * will relay to.
     * @param plainTextProxyRandomPort The port of the HTTP proxy running
     * only locally and accepting plain-text sockets.
     */
    public XmppHandler(final int sslProxyRandomPort, 
        final int plainTextProxyRandomPort, final SystemTray tray) {
        this.sslProxyRandomPort = sslProxyRandomPort;
        this.tray = tray;
        this.email = LanternUtils.getStringProperty("google.user");
        this.pwd = LanternUtils.getStringProperty("google.pwd");
        if (StringUtils.isBlank(this.email)) {
            log.error("No user name");
            throw new IllegalStateException("No user name");
        }
        
        if (StringUtils.isBlank(this.pwd)) {
            log.error("No password.");
            throw new IllegalStateException("No password");
        }
        
        try {
            final String libName = System.mapLibraryName("jnltorrent");
            final JLibTorrent libTorrent = 
                new JLibTorrent(Arrays.asList(new File (new File(".."), 
                    libName), new File (libName), new File ("lib", libName)), true);
            
            //final SocketFactory socketFactory = newTlsSocketFactory();
            //final ServerSocketFactory serverSocketFactory =
            //    newTlsServerSocketFactory();

            final InetSocketAddress plainTextProxyRelayAddress = 
                new InetSocketAddress("127.0.0.1", plainTextProxyRandomPort);
            
            this.client = P2P.newXmppP2PHttpClient("shoot", libTorrent, 
                libTorrent, new InetSocketAddress(this.sslProxyRandomPort), 
                SocketFactory.getDefault(), ServerSocketFactory.getDefault(), 
                plainTextProxyRelayAddress);

            // This is a global, backup listener added to the client. We might
            // get notifications of messages twice in some cases, but that's
            // better than the alternative of sometimes not being notified
            // at all.
            log.info("Adding message listener...");
            this.client.addMessageListener(typedListener);
            this.client.login(this.email, this.pwd, ID);
            final XMPPConnection connection = this.client.getXmppConnection();
            log.info("Connection ID: {}", connection.getConnectionID());
            
            // Here we handle allowing the server to subscribe to our presence.
            connection.addPacketListener(new PacketListener() {
                
                @Override
                public void processPacket(final Packet pack) {
                    //log.info("Got packet: {}", pack);
                    log.info("Responding to subscribtion request from {} and to {}", 
                        pack.getFrom(), pack.getTo());
                    final Presence packet = 
                        new Presence(Presence.Type.subscribed);
                    packet.setTo(pack.getFrom());
                    packet.setFrom(pack.getTo());
                    connection.sendPacket(packet);
                }
            }, new PacketFilter() {
                
                @Override
                public boolean accept(final Packet packet) {
                    //log.info("Filtering incoming packet:\n{}", packet.toXML());
                    if(packet instanceof Presence) {
                        final Presence pres = (Presence) packet;
                        if(pres.getType().equals(Presence.Type.subscribe)) {
                            log.info("Got subscribe packet!!");
                            final String from = pres.getFrom();
                            if (from.startsWith("lantern-controller@") &&
                                from.endsWith("lantern-controller.appspotchat.com")) {
                                log.info("Got lantern subscription request!!");
                                return true;
                            } else {
                                log.info("Ignoring subscription request from: {}",
                                    from);
                            }
                            
                        }
                    } else {
                        log.info("Filtered out packet: ", packet.toXML());
                        //XmppUtils.printMessage(packet);
                    }
                    return false;
                }
            });
            updatePresence();
            final ChatManager chatManager = connection.getChatManager();
            this.hubChat = 
                chatManager.createChat(LANTERN_JID, typedListener);
            sendInfoRequest();
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

    private void updatePresence() {
        ProviderManager.getInstance().addIQProvider(
            "query", "google:shared-status", new GenericIQProvider());
        
        // This is for Google Talk compatibility. Surprising, all we need to
        // do is grab our Google Talk shared status, signifying support for
        // their protocol, and then we don't interfere with GChat visibility.
        final Packet status = LanternUtils.getSharedStatus(
                this.client.getXmppConnection());
        log.info("Status:\n{}", status.toXML());
        final XMPPConnection conn = this.client.getXmppConnection();
        
        log.info("Sending presence available");
        conn.sendPacket(new Presence(Presence.Type.available));
        
        final Presence forHub = new Presence(Presence.Type.available);
        forHub.setTo(LANTERN_JID);
        conn.sendPacket(forHub);
    }

    private void configureRoster() throws XMPPException {
        final XMPPConnection xmpp = this.client.getXmppConnection();

        final Roster roster = xmpp.getRoster();
        // Make sure we look for Lantern packets.
        final RosterEntry lantern = roster.getEntry(LANTERN_JID);
        if (lantern == null) {
            log.info("Creating roster entry for Lantern...");
            roster.createEntry(LANTERN_JID, "Lantern", null);
        }
        
        roster.setSubscriptionMode(Roster.SubscriptionMode.manual);
        
        roster.addRosterListener(new RosterListener() {
            @Override
            public void entriesDeleted(final Collection<String> addresses) {
                log.info("Entries deleted");
            }
            @Override
            public void entriesUpdated(final Collection<String> addresses) {
                log.info("Entries updated: {}", addresses);
            }
            @Override
            public void presenceChanged(final Presence presence) {
                //log.info("Processing presence changed: {}", presence);
                processPresence(presence);
            }
            @Override
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
                processPresence(p);
            }
        }
        log.info("Finished adding listeners");
    }

    
    private void processPresence(final Presence p) {
        final String from = p.getFrom();
        log.info("Got presence: {}", p.toXML());
        if (isLanternHub(from)) {
            log.info("Got Lantern hub presence");
        }
        else if (isLanternJid(from)) {
            addOrRemovePeer(p, from);
        }
    }

    private void sendInfoRequest() {
        // Send an "info" message to gather proxy data.
        final Message msg = new Message();
        final JSONObject json = new JSONObject();
        final StatsTracker statsTracker = LanternHub.statsTracker();
        json.put(LanternConstants.COUNTRY_CODE, CensoredUtils.countryCode());
        //json.put(LanternConstants.USER_NAME, this.user);
        //json.put(LanternConstants.PASSWORD, this.pwd);
        json.put(LanternConstants.BYTES_PROXIED, 
            statsTracker.getBytesProxied());
        json.put(LanternConstants.DIRECT_BYTES, 
            statsTracker.getDirectBytes());
        json.put(LanternConstants.REQUESTS_PROXIED, 
            statsTracker.getProxiedRequests());
        json.put(LanternConstants.DIRECT_REQUESTS, 
            statsTracker.getDirectRequests());
        json.put(LanternConstants.WHITELIST_ADDITIONS, 
            LanternUtils.toJsonArray(Whitelist.getAdditions()));
        json.put(LanternConstants.WHITELIST_REMOVALS, 
            LanternUtils.toJsonArray(Whitelist.getRemovals()));
        json.put(LanternConstants.VERSION_KEY, LanternConstants.VERSION);
        final String str = json.toJSONString();
        log.info("Reporting data: {}", str);
        msg.setBody(str);
        try {
            log.info("Sending info message to Lantern Hub");
            this.hubChat.sendMessage(msg);
            Whitelist.whitelistReported();
            statsTracker.clear();
        } catch (final XMPPException e) {
            log.error("Could not send INFO message", e);
        }
    }

    private void addOrRemovePeer(final Presence p, final String from) {
        log.info("Processing peer: {}", from);
        final URI uri;
        try {
            uri = new URI(from);
        } catch (final URISyntaxException e) {
            log.error("Could not create URI from: {}", from);
            return;
        }
        final TrustedContactsManager tcm = 
            LanternHub.getTrustedContactsManager();
        final boolean trusted = tcm.isJidTrusted(from);
        if (p.isAvailable()) {
            log.info("Adding from to peer JIDs: {}", from);
            if (trusted) {
                addPeerProxy(uri);
            } else {
                addAnonymousProxy(uri);
            }
        }
        else {
            log.info("Removing JID for peer '"+from+"' with presence: {}", p);
            removePeer(uri);
        }
    }

    private boolean isLanternHub(final String from) {
        return from.startsWith("lantern-controller@") && 
            from.contains("lantern-controller.appspot");
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
    
    /*
    private void processTypedMessage(final Message msg, final Integer type, 
        final Chat chat) {
        final String from = chat.getParticipant();
        final URI uri;
        try {
            uri = new URI(from);
        } catch (final URISyntaxException e) {
            log.error("Could not create URI from: {}", from);
            return;
        }
        log.info("Processing typed message from {}", from);
        if (!this.peerProxySet.contains(uri)) {
            log.warn("Ignoring message from untrusted peer: {}", from);
            log.warn("Peer not in: {}", this.peerProxySet);
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
    */
    
    private void processInfoData(final Message msg, final Chat chat) {
        log.info("Processing INFO data from request or response.");
        final String proxyString = 
            (String) msg.getProperty(XmppMessageConstants.PROXIES);
        if (StringUtils.isNotBlank(proxyString)) {
            log.info("Got proxies: {}", proxyString);
            final Scanner scan = new Scanner(proxyString);
            while (scan.hasNext()) {
                final String cur = scan.next();
                addProxy(cur, chat);
            }
        }
        
        //final String mac =
        //    (String) msg.getProperty(P2PConstants.MAC);
        final String base64Cert =
            (String) msg.getProperty(P2PConstants.CERT);
        log.info("Base 64 cert: {}", base64Cert);
        
        final String secret =
            (String) msg.getProperty(P2PConstants.SECRET_KEY);
        log.info("Secret key: {}", secret);
        if (StringUtils.isNotBlank(secret)) {
            final URI uri;
            try {
                uri = new URI(chat.getParticipant());
            } catch (final URISyntaxException e) {
                log.error("Could not create URI from: {}", 
                    chat.getParticipant());
                return;
            }
            synchronized (peerProxySet) {
                if (!peerProxySet.contains(uri)) {
                    peerProxies.add(uri);
                    peerProxySet.add(uri);
                }
            }
        }
        
        /*
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
        */
    }

    private void addProxy(final String cur, final Chat chat) {
        log.info("Considering proxy: {}", cur);
        final String jid = this.client.getXmppConnection().getUser().trim();
        final String emailId = LanternUtils.jidToUser(jid);
        log.info("We are: {}", jid);
        log.info("Service name: {}",
             this.client.getXmppConnection().getServiceName());
        if (jid.equals(cur.trim())) {
            log.info("Not adding ourselves as a proxy!!");
            return;
        }
        if (cur.contains("appspot")) {
            addLaeProxy(cur, chat);
        } else if (cur.startsWith(emailId+"/")) {
            try {
                addTrustedProxy(new URI(cur));
            } catch (final URISyntaxException e) {
                log.error("Error with proxy URI", e);
            }
        } else if (cur.contains("@")) {
            try {
                addAnonymousProxy(new URI(cur));
            } catch (final URISyntaxException e) {
                log.error("Error with proxy URI", e);
            }
        } else {
            addGeneralProxy(cur, chat);
        }
    }

    private void addTrustedProxy(final URI cur) {
        log.info("Considering trusted peer proxy: {}", cur);
        addPeerProxy(cur, this.peerProxySet, this.peerProxies);
    }
    
    private void addAnonymousProxy(final URI cur) {
        log.info("Considering Lantern proxy");
        addPeerProxy(cur, this.anonymousProxySet, this.anonymousProxies);
    }
    
    private void addPeerProxy(final URI cur) {
        log.info("Considering Lantern peer proxy");
        addPeerProxy(cur, this.peerProxySet, this.peerProxies);
    }
    
    private void addPeerProxy(final URI cur, final Set<URI> peerSet, 
        final Queue<URI> peerQueue) {
        log.info("Considering peer proxy");
        /*
        if (!cur.toASCIIString().startsWith("rach")) {
            log.info("Ignoring user for now: "+cur);
            return;
        }
        */
        synchronized (peerSet) {
            if (!peerSet.contains(cur)) {
                log.info("Actually adding peer proxy: {}", cur);
                peerSet.add(cur);
                peerQueue.add(cur);
            } else {
                log.info("We already know about the peer proxy");
            }
        }
    }

    private void addLaeProxy(final String cur, final Chat chat) {
        log.info("Adding LAE proxy");
        addProxyWithChecks(this.laeProxySet, this.laeProxies, 
            new ProxyHolder(cur, new InetSocketAddress(cur, 443)), chat);
    }
    
    private void addGeneralProxy(final String cur, final Chat chat) {
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
    
    private final Map<String, String> secretKeys = 
        new ConcurrentHashMap<String, String>();

    private String getSecretKey(final String jid) {
        synchronized (secretKeys) {
            if (secretKeys.containsKey(jid)) {
                return secretKeys.get(jid);
            }
            final String key = CommonUtils.generateBase64Key();
            secretKeys.put(jid, key);
            return key;
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

    
    @Override
    public void onCouldNotConnect(final InetSocketAddress proxyAddress) {
        // This can happen in several scenarios. First, it can happen if you've
        // actually disconnected from the internet. Second, it can happen if
        // the proxy is blocked. Third, it can happen when the proxy is simply
        // down for some reason.
        log.info("COULD NOT CONNECT TO STANDARD PROXY!! Proxy address: {}", 
            proxyAddress);
        
        // For now we assume this is because we've lost our connection.
        //onCouldNotConnect(new ProxyHolder(proxyAddress.getHostName(), proxyAddress), 
        //    this.proxySet, this.proxies);
    }
    
    @Override
    public void onCouldNotConnectToLae(final InetSocketAddress proxyAddress) {
        log.info("COULD NOT CONNECT TO LAE PROXY!! Proxy address: {}", 
            proxyAddress);
        
        // For now we assume this is because we've lost our connection.
        
        //onCouldNotConnect(new ProxyHolder(proxyAddress.getHostName(), proxyAddress), 
        //    this.laeProxySet, this.laeProxies);
    }
    
    private void onCouldNotConnect(final ProxyHolder proxyAddress,
        final Set<ProxyHolder> set, final Queue<ProxyHolder> queue){
        log.info("COULD NOT CONNECT!! Proxy address: {}", proxyAddress);
        synchronized (this.proxySet) {
            set.remove(proxyAddress);
            queue.remove(proxyAddress);
        }
    }

    @Override
    public void onCouldNotConnectToPeer(final URI peerUri) {
        removePeer(peerUri);
    }
    
    @Override
    public void onError(final URI peerUri) {
        removePeer(peerUri);
    }

    private void removePeer(final URI uri) {
        // We always remove from both since their trusted status could have
        // changed 
        removePeerUri(uri);
        removeAnonymousPeerUri(uri);
    }
    
    private void removePeerUri(final URI peerUri) {
        log.info("Removing peer with URI: {}", peerUri);
        remove(peerUri, this.peerProxySet, this.peerProxies);
    }

    private void removeAnonymousPeerUri(final URI peerUri) {
        log.info("Removing anonymous peer with URI: {}", peerUri);
        remove(peerUri, this.anonymousProxySet, this.anonymousProxies);
    }
    
    private void remove(final URI peerUri, final Set<URI> set, 
        final Queue<URI> queue) {
        log.info("Removing peer with URI: {}", peerUri);
        synchronized (set) {
            set.remove(peerUri);
            queue.remove(peerUri);
        }
    }
    
    @Override
    public InetSocketAddress getLaeProxy() {
        return getProxy(this.laeProxies);
    }
    
    @Override
    public InetSocketAddress getProxy() {
        return getProxy(this.proxies);
    }
    
    @Override
    public URI getAnonymousProxy() {
        log.info("Getting anonymous proxy");
        return getProxyUri(this.anonymousProxies);
    }

    @Override
    public URI getPeerProxy() {
        log.info("Getting peer proxy");
        final URI proxy = getProxyUri(this.peerProxies);
        if (proxy == null) {
            log.info("Peer proxies {} and anonymous proxies {}", 
                this.peerProxies, this.anonymousProxies);
        }
        return proxy;
    }
    
    private URI getProxyUri(final Queue<URI> queue) {
        if (queue.isEmpty()) {
            log.info("No proxy URIs");
            return null;
        }
        final URI proxy = queue.remove();
        queue.add(proxy);
        log.info("FIFO queue is now: {}", queue);
        return proxy;
    }

    private InetSocketAddress getProxy(final Queue<ProxyHolder> queue) {
        if (queue.isEmpty()) {
            log.info("No proxy addresses");
            return null;
        }
        final ProxyHolder proxy = queue.remove();
        queue.add(proxy);
        log.info("FIFO queue is now: {}", queue);
        return proxy.isa;
    }

    public XmppP2PClient getP2PClient() {
        return client;
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
