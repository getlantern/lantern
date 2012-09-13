package org.lantern;

import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Queue;
import java.util.Set;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicReference;

import javax.management.InstanceAlreadyExistsException;
import javax.management.MBeanRegistrationException;
import javax.management.MBeanServer;
import javax.management.MalformedObjectNameException;
import javax.management.NotCompliantMBeanException;
import javax.management.ObjectName;
import javax.security.auth.login.CredentialException;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.MessageListener;
import org.jivesoftware.smack.PacketListener;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.SmackConfiguration;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.filter.PacketFilter;
import org.jivesoftware.smack.packet.Message;
import org.jivesoftware.smack.packet.Packet;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smack.packet.Presence.Type;
import org.jivesoftware.smackx.packet.VCard;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.lastbamboo.common.p2p.P2PConnectionEvent;
import org.lastbamboo.common.p2p.P2PConnectionListener;
import org.lastbamboo.common.p2p.P2PConstants;
import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.lastbamboo.common.portmapping.UpnpService;
import org.lastbamboo.common.stun.client.StunServerRepository;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.littleshoot.p2p.P2P;
import org.littleshoot.util.SessionSocketListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.hoodcomputing.natpmp.NatPmpException;

/**
 * Handles logging in to the XMPP server and processing trusted users through
 * the roster.
 */
public class DefaultXmppHandler implements XmppHandler {
    
    private static final Logger LOG = 
        LoggerFactory.getLogger(DefaultXmppHandler.class);
    
    /**
     * These are the centralized proxies this Lantern instance is using.
     */
    private final Set<ProxyHolder> proxySet =
        new HashSet<ProxyHolder>();
    private final Queue<ProxyHolder> proxies = 
        new ConcurrentLinkedQueue<ProxyHolder>();
    
    /**
     * This is the set of all peer proxies we know about. We may have 
     * established connections with some of them. The main purpose of this is
     * to avoid exchanging keys multiple times.
     */
    private final Set<URI> peerProxySet = new HashSet<URI>();
    
    private final Set<ProxyHolder> laeProxySet =
        new HashSet<ProxyHolder>();
    private final Queue<ProxyHolder> laeProxies = 
        new ConcurrentLinkedQueue<ProxyHolder>();

    private final AtomicReference<XmppP2PClient> client = 
        new AtomicReference<XmppP2PClient>();
    
    static {
        SmackConfiguration.setPacketReplyTimeout(30 * 1000);
    }

    private final Timer updateTimer = LanternHub.timer();

    private volatile long lastInfoMessageScheduled = 0L;
    
    private final MessageListener typedListener = new MessageListener() {
        @Override
        public void processMessage(final Chat ch, final Message msg) {
            // Note the Chat will always be null here. We try to avoid using
            // actual Chat instances due to Smack's strange and inconsistent
            // behavior with message listeners on chats.
            final String part = msg.getFrom();
            LOG.info("Got chat participant: {} with message:\n {}", part, 
                msg.toXML());
            if (StringUtils.isNotBlank(part) && 
                part.startsWith(LanternConstants.LANTERN_JID)) {
                processLanternHubMessage(msg);
            }

            final Integer type = 
                (Integer) msg.getProperty(P2PConstants.MESSAGE_TYPE);
            if (type != null) {
                LOG.info("Not processing typed message");
                processTypedMessage(msg, type);
            } 
        }
    };

    private String lastJson = "";

    private String hubAddress;

    private final org.lantern.Roster roster = new org.lantern.Roster(this);

    private GoogleTalkState state;

    private String lastUserName;

    private String lastPass;
    
    private final NatPmpService natPmpService;

    private final UpnpService upnpService = new Upnp();

    private ClosedBetaEvent closedBetaEvent;
    
    private final Object closedBetaLock = new Object();

    /**
     * Creates a new XMPP handler.
     */
    public DefaultXmppHandler() {
        // This just links connectivity with Google Talk login status when 
        // running in give mode.
        NatPmpService temp = null;
        try {
            temp = new NatPmp();
        } catch (final NatPmpException e) {
            // This will happen when NAT-PMP is not supported on the local 
            // network.
            LOG.info("Could not map", e);
            // We just use a dummy one in this case.
            temp = new NatPmpService() {
                @Override
                public void removeNatPmpMapping(int arg0) {
                }
                @Override
                public int addNatPmpMapping(
                    final PortMappingProtocol arg0, int arg1, int arg2,
                    PortMapListener arg3) {
                    return -1;
                }
                @Override
                public void shutdown() {
                }
            };
        }
        natPmpService = temp;
        
        new GiveModeConnectivityHandler();
        LanternUtils.configureXmpp();
        prepopulateProxies();
        LanternHub.register(this);
        //setupJmx();
    }
    
    @Subscribe
    public void onAuthStatus(final GoogleTalkStateEvent ase) {
        this.state = ase.getState();
        switch (state) {
        case LOGGED_IN:
            // We wait until we're logged in before creating our roster.
            this.roster.loggedIn();
            //LanternHub.asyncEventBus().post(new SyncEvent());
            synchronized (this.rosterLock) {
                this.rosterLock.notifyAll();
            }
            break;
        case LOGGED_OUT:
            this.roster.reset();
            break;
        case LOGGING_IN:
            break;
        case LOGGING_OUT:
            break;
        case LOGIN_FAILED:
            this.roster.reset();
            break;
        }
    }
    
    private void prepopulateProxies() {
        // Add all the stored proxies.
        final Collection<String> saved = LanternHub.settings().getProxies();
        LOG.info("Proxy set is: {}", saved);
        for (final String proxy : saved) {
            // Don't use peer proxies since we're not connected to XMPP yet.
            if (!proxy.contains("@")) {
                LOG.info("Adding prepopulated proxy: {}", proxy);
                addProxy(proxy);
            }
        }
    }

    @Override
    public void connect() throws IOException, CredentialException, 
        NotInClosedBetaException {
        if (!LanternUtils.isConfigured() && LanternHub.settings().isUiEnabled()) {
            LOG.info("Not connecting when not configured");
            return;
        }
        LOG.info("Connecting to XMPP servers...");
        String email = LanternHub.settings().getEmail();
        String pwd = LanternHub.settings().getPassword();
        if (StringUtils.isBlank(email)) {
            if (!LanternHub.settings().isUiEnabled()) {
                email = askForEmail();
                pwd = askForPassword();
                LanternHub.settings().setEmail(email);
                LanternHub.settings().setPassword(pwd);
            } else {
                LOG.error("No user name");
                throw new IllegalStateException("No user name");
            }
            LanternHub.settingsIo().write();
        }
        
        if (StringUtils.isBlank(pwd)) {
            if (!LanternHub.settings().isUiEnabled()) {
                pwd = askForPassword();
                LanternHub.settings().setPassword(pwd);
            } else {
                LOG.error("No password.");
                throw new IllegalStateException("No password");
            }
            LanternHub.settingsIo().write();
        }
        connect(email, pwd);
    }
    
    @Override
    public void connect(final String email, final String pwd) 
        throws IOException, CredentialException, NotInClosedBetaException {
        LOG.debug("Connecting to XMPP servers with user name and password...");
        this.lastUserName = email;
        this.lastPass = pwd;
        final InetSocketAddress plainTextProxyRelayAddress = 
            new InetSocketAddress("127.0.0.1", 
                LanternUtils.PLAINTEXT_LOCALHOST_PROXY_PORT);
        
        final SessionSocketListener sessionListener = new SessionSocketListener() {
            
            @Override
            public void reconnected() {
                // We need to send a new presence message each time we 
                // reconnect to the XMPP server, as otherwise peers won't 
                // know we're available and we won't get data from the bot.
                updatePresence();
            }
            
            @Override
            public void onSocket(String arg0, Socket arg1) throws IOException {
            }
        };
        this.client.set(P2P.newXmppP2PHttpClient("shoot", natPmpService, 
            upnpService, new InetSocketAddress(LanternHub.settings().getServerPort()), 
            //newTlsSocketFactory(),ç SSLServerSocketFactory.getDefault(),//newTlsServerSocketFactory(),
            LanternUtils.newTlsSocketFactory(), LanternUtils.newTlsServerSocketFactory(),
            //SocketFactory.getDefault(), ServerSocketFactory.getDefault(), 
            plainTextProxyRelayAddress, sessionListener, false));
        
        this.client.get().addConnectionListener(new P2PConnectionListener() {
            
            @Override
            public void onConnectivityEvent(final P2PConnectionEvent event) {
                LOG.info("Got connectivity event: {}", event);
                LanternHub.asyncEventBus().post(event);
            }
        });
        
        // This is a global, backup listener added to the client. We might
        // get notifications of messages twice in some cases, but that's
        // better than the alternative of sometimes not being notified
        // at all.
        LOG.info("Adding message listener...");
        this.client.get().addMessageListener(typedListener);
        
        if (this.proxies.isEmpty()) {
            connectivityEvent(ConnectivityStatus.CONNECTING);
        }
        LanternHub.eventBus().post(
            new GoogleTalkStateEvent(GoogleTalkState.LOGGING_IN));
        final String id;
        if (LanternHub.settings().isGetMode()) {
            LOG.info("Setting ID for get mode...");
            id = "gmail.";
        } else {
            LOG.info("Setting ID for give mode");
            id = LanternConstants.UNCENSORED_ID;
        }

        try {
            this.client.get().login(email, pwd, id);
            LanternHub.eventBus().post(
                new GoogleTalkStateEvent(GoogleTalkState.LOGGED_IN));
        } catch (final IOException e) {
            if (this.proxies.isEmpty()) {
                connectivityEvent(ConnectivityStatus.DISCONNECTED);
            }
            LanternHub.eventBus().post(
                new GoogleTalkStateEvent(GoogleTalkState.LOGIN_FAILED));
            LanternHub.settings().setPasswordSaved(false);
            LanternHub.settings().setStoredPassword("");
            LanternHub.settings().setPassword("");
            throw e;
        } catch (final CredentialException e) {
            if (this.proxies.isEmpty()) {
                connectivityEvent(ConnectivityStatus.DISCONNECTED);
            }
            LanternHub.eventBus().post(
                new GoogleTalkStateEvent(GoogleTalkState.LOGIN_FAILED));
            throw e;
        }
        
        // Note we don't consider ourselves connected in get mode until we 
        // actually get proxies to work with.
        final XMPPConnection connection = this.client.get().getXmppConnection();
        final Collection<InetSocketAddress> googleStunServers = 
            XmppUtils.googleStunServers(connection);
        StunServerRepository.setStunServers(googleStunServers);
        LanternHub.settings().setStunServers(
            new HashSet<String>(toStringServers(googleStunServers)));
        
        // Make sure all connections between us and the server are stored
        // OTR.
        LanternUtils.activateOtr(connection);
        
        LOG.info("Connection ID: {}", connection.getConnectionID());
        
        // Here we handle allowing the server to subscribe to our presence.
        connection.addPacketListener(new PacketListener() {
            
            @Override
            public void processPacket(final Packet pack) {
                final Presence pres = (Presence) pack;
                LOG.debug("Processing packet!! {}", pres);
                final String from = pres.getFrom();
                LOG.debug("Responding to presence from {} and to {}", 
                    from, pack.getTo());

                final Type type = pres.getType();
                // Allow subscription requests from the lantern bot.
                if (from.startsWith("lanternctrl@") &&
                    from.endsWith("lanternctrl.appspotchat.com")) {
                    if (type == Type.subscribe) {
                        final Presence packet = 
                            new Presence(Presence.Type.subscribed);
                        packet.setTo(from);
                        packet.setFrom(pack.getTo());
                        connection.sendPacket(packet);
                    } else {
                        LOG.info("Non-subscribe packet from hub? {}", 
                            pres.toXML());
                    }
                } else {
                    switch (type) {
                    case available:
                        return;
                    case error:
                        LOG.warn("Got error packet!! {}", pack.toXML());
                        return;
                    case subscribe:
                        LOG.info("Adding subscription request from: {}", from);
                        
                        // If we get a subscription request from someone 
                        // already on our roster, auto-accept it.
                        if (roster.autoAcceptSubscription(from)) {
                            subscribed(from);
                        }
                        roster.addIncomingSubscriptionRequest(from);
                        break;
                    case subscribed:
                        break;
                    case unavailable:
                        return;
                    case unsubscribe:
                        LOG.info("Removing subscription request from: {}",from);
                        roster.removeIncomingSubscriptionRequest(from);
                        return;
                    case unsubscribed:
                        break;
                    }
                }
            }
        }, new PacketFilter() {
            
            @Override
            public boolean accept(final Packet packet) {
                if(packet instanceof Presence) {
                    return true;
                } else {
                    LOG.debug("Not a presence packet: {}", packet.toXML());
                }
                return false;
            }
        });
        
        gTalkSharedStatus();
        updatePresence();
        if (LanternHub.settings().isInClosedBeta()) {
            LOG.debug("Already in closed beta...");
            return;
        }
        
        synchronized (this.closedBetaLock) {
            if (this.closedBetaEvent == null) {
                try {
                    this.closedBetaLock.wait(60 * 1000);
                } catch (final InterruptedException e) {
                    LOG.info("Interrupted? Maybe on shutdown?", e);
                }
            }
        }
        if (this.closedBetaEvent != null) {
            if(!this.closedBetaEvent.isInClosedBeta()) {
                LOG.debug("Not in closed beta...");
                notInClosedBeta("Not in closed beta");
            } else {
                LOG.info("Server notified us we're in the closed beta!");
            }
        } else {
            LOG.warn("No closed beta event -- timed out!!");
            notInClosedBeta("No closed beta event!!");
        }
    }
    

    private void notInClosedBeta(final String msg) 
        throws NotInClosedBetaException {
        //connectivityEvent(ConnectivityStatus.DISCONNECTED);
        disconnect();
        throw new NotInClosedBetaException(msg);
    }

    private Set<String> toStringServers(
        final Collection<InetSocketAddress> googleStunServers) {
        final Set<String> strings = new HashSet<String>();
        for (final InetSocketAddress isa : googleStunServers) {
            strings.add(isa.getHostName()+":"+isa.getPort());
        }
        return strings;
    }

    private void connectivityEvent(final ConnectivityStatus cs) {
        if (LanternHub.settings().isGetMode()) {
            LanternHub.eventBus().post(
                new ConnectivityStatusChangeEvent(cs));
        } else {
            LOG.info("Ignoring connectivity event in give mode..");
        }
    }

    @Override
    public void clearProxies() {
        this.proxies.clear();
        this.proxySet.clear();
        this.peerProxySet.clear();
        this.laeProxySet.clear();
        this.laeProxies.clear();
    }
    
    @Override
    public void disconnect() {
        if (this.client.get() == null) {
            LOG.info("Not disconnecting since we're not yet connected");
            return;
        }
        LOG.info("Disconnecting!!");
        lastJson = "";
        LanternHub.eventBus().post(
            new GoogleTalkStateEvent(GoogleTalkState.LOGGING_OUT));
        
        this.client.get().logout();
        this.client.set(null);
        
        if (this.proxies.isEmpty()) {
            connectivityEvent(ConnectivityStatus.DISCONNECTED);
        }
        LanternHub.eventBus().post(
            new GoogleTalkStateEvent(GoogleTalkState.LOGGED_OUT));
        
        peerProxySet.clear();
    }

    private void processLanternHubMessage(final Message msg) {
        LOG.debug("Lantern controlling agent response");
        this.hubAddress = msg.getFrom();
        LOG.debug("Set hub address to: {}", hubAddress);
        final String body = msg.getBody();
        LOG.debug("Body: {}", body);
        final Object obj = JSONValue.parse(body);
        final JSONObject json = (JSONObject) obj;
        
        final Boolean inClosedBeta = 
            (Boolean) json.get(LanternConstants.INVITED);
        
        if (inClosedBeta != null) {
            LanternHub.settings().setInClosedBeta(inClosedBeta);
            LanternHub.asyncEventBus().post(new ClosedBetaEvent(inClosedBeta));
            if (!inClosedBeta) {
                //return;
            }
        } else {
            LanternHub.settings().setInClosedBeta(false);
            LanternHub.asyncEventBus().post(new ClosedBetaEvent(false));
            //return;
        }
                
        final JSONArray servers = 
            (JSONArray) json.get(LanternConstants.SERVERS);
        final Long delay = 
            (Long) json.get(LanternConstants.UPDATE_TIME);
        LOG.debug("Server sent delay of: "+delay);
        if (delay != null) {
            final long now = System.currentTimeMillis();
            final long elapsed = now - lastInfoMessageScheduled;
            if (elapsed > 10000 && delay != 0L) {
                lastInfoMessageScheduled = now;
                updateTimer.schedule(new TimerTask() {
                    @Override
                    public void run() {
                        updatePresence();
                    }
                }, delay);
                LOG.debug("Scheduled next info request in {} milliseconds", 
                    delay);
            } else {
                LOG.debug("Ignoring duplicate info request scheduling- "+
                    "scheduled request {} milliseconds ago.", elapsed);
            }
        }
        
        if (servers == null) {
            LOG.debug("No servers in message");
        } else {
            final Iterator<String> iter = servers.iterator();
            while (iter.hasNext()) {
                final String server = iter.next();
                addProxy(server);
            }
        }

        // This is really a JSONObject, but that itself is a map.
        final JSONObject update = 
            (JSONObject) json.get(LanternConstants.UPDATE_KEY);
        if (update != null) {
            LOG.info("About to propagate update...");
            LanternHub.display().asyncExec (new Runnable () {
                @Override
                public void run () {
                    final Map<String, Object> event = 
                        new HashMap<String, Object>();
                    event.putAll(update);
                    LanternHub.asyncEventBus().post(new UpdateEvent(event));
                }
            });
        }
        
        final Long invites = 
            (Long) json.get(LanternConstants.INVITES_KEY);
        if (invites != null) {
            LOG.info("Setting invites to: {}", invites);
            LanternHub.settings().setInvites(invites.intValue());
        }
    }
    
    @Subscribe
    public void onClosedBetaEvent(final ClosedBetaEvent cbe) {
        LOG.debug("Got closed beta event!!");
        this.closedBetaEvent = cbe;
        
        synchronized (this.closedBetaLock) {
            this.closedBetaLock.notifyAll();
        }
    }

    private void gTalkSharedStatus() {
        // This is for Google Talk compatibility. Surprising, all we need to
        // do is grab our Google Talk shared status, signifying support for
        // their protocol, and then we don't interfere with GChat visibility.
        final Packet status = XmppUtils.getSharedStatus(
                this.client.get().getXmppConnection());
        LOG.info("Status:\n{}", status.toXML());
    }

    private String askForEmail() {
        try {
            System.out.print("Please enter your gmail e-mail, as in johndoe@gmail.com: ");
            return LanternUtils.readLineCLI();
        } catch (final IOException e) {
            final String msg = "IO error trying to read your email address!";
            System.out.println(msg);
            LOG.error(msg, e);
            throw new IllegalStateException(msg, e);
        }
    }
    
    private String askForPassword() {
        try {
            System.out.print("Please enter your gmail password: ");
            return new String(LanternUtils.readPasswordCLI());
        } catch (IOException e) {
            final String msg = "IO error trying to read your email address!";
            System.out.println(msg);
            LOG.error(msg, e);
            throw new IllegalStateException(msg, e);
        }
    }

    /**
     * Updates the user's presence. We also include any stats updates in this 
     * message. Note that periodic presence updates are also used on the server
     * side to verify which clients are actually available.
     * 
     * We in part send presence updates instead of typical chat messages to 
     * get around these messages showing up in the user's gchat window.
     */
    private void updatePresence() {
        if (!isLoggedIn()) {
            LOG.info("Not updating presence when we're not connected");
            return;
        }
        
        final XMPPConnection conn = this.client.get().getXmppConnection();

        LOG.info("Sending presence available");
        
        // OK, this is bizarre. For whatever reason, we **have** to send the
        // following packet in order to get presence events from our peers.
        // DO NOT REMOVE THIS MESSAGE!! See XMPP spec.
        final Presence pres = new Presence(Presence.Type.available);
        conn.sendPacket(pres);
        
        final Presence forHub = new Presence(Presence.Type.available);
        forHub.setTo(LanternConstants.LANTERN_JID);
        
        //if (!LanternHub.settings().isGetMode()) {
            final String str = 
                LanternUtils.jsonify(LanternHub.statsTracker());
            LOG.debug("Reporting data: {}", str);
            if (!this.lastJson.equals(str)) {
                this.lastJson = str;
                forHub.setProperty("stats", str);
                LanternHub.statsTracker().resetCumulativeStats();
            } else {
                LOG.info("No new stats to report");
            }
        //} else {
        //    LOG.info("Not reporting any stats in get mode");
        //}
        
        conn.sendPacket(forHub);
    }

    /*
    private void sendInfoRequest() {
        // Send an "info" message to gather proxy data.
        LOG.info("Sending INFO request");
        final Message msg = new Message();
        msg.setType(Type.chat);
        //msg.setType(Type.normal);
        msg.setTo(LanternConstants.LANTERN_JID);
        msg.setFrom(this.client.getXmppConnection().getUser());
        final JSONObject json = new JSONObject();
        final StatsTracker statsTracker = LanternHub.statsTracker();
        json.put(LanternConstants.COUNTRY_CODE, CensoredUtils.countryCode());
        json.put(LanternConstants.BYTES_PROXIED, 
            statsTracker.getTotalBytesProxied());
        json.put(LanternConstants.DIRECT_BYTES, 
            statsTracker.getDirectBytes());
        json.put(LanternConstants.REQUESTS_PROXIED, 
            statsTracker.getTotalProxiedRequests());
        json.put(LanternConstants.DIRECT_REQUESTS, 
            statsTracker.getDirectRequests());
        json.put(LanternConstants.WHITELIST_ADDITIONS, 
            LanternUtils.toJsonArray(Whitelist.getAdditions()));
        json.put(LanternConstants.WHITELIST_REMOVALS, 
            LanternUtils.toJsonArray(Whitelist.getRemovals()));
        json.put(LanternConstants.VERSION_KEY, LanternConstants.VERSION);
        final String str = json.toJSONString();
        LOG.info("Reporting data: {}", str);
        msg.setBody(str);
        
        this.client.getXmppConnection().sendPacket(msg);
        Whitelist.whitelistReported();
        //statsTracker.clear();
    }
    */

    @Override
    public void addOrRemovePeer(final Presence p, final String from) {
        LOG.info("Processing peer: {}", from);
        final URI uri;
        try {
            uri = new URI(from);
        } catch (final URISyntaxException e) {
            LOG.error("Could not create URI from: {}", from);
            return;
        }
        if (p.isAvailable()) {
            LOG.info("Processing available peer");
            // OK, we just request a certificate every time we get a present 
            // peer. If we get a response, this peer will be added to active
            // peer URIs.
            sendAndRequestCert(uri);
        }
        else {
            LOG.info("Removing JID for peer '"+from);
            removePeer(uri);
        }
    }

    private void sendErrorMessage(final InetSocketAddress isa,
        final String message) {
        final Message msg = new Message();
        msg.setProperty(P2PConstants.MESSAGE_TYPE, 
            XmppMessageConstants.ERROR_TYPE);
        final String errorMessage = "Error: "+message+" with host: "+isa;
        msg.setProperty(XmppMessageConstants.MESSAGE, errorMessage);
        if (isLoggedIn()) {
            final XMPPConnection conn = this.client.get().getXmppConnection();
            conn.sendPacket(msg);
        }
    }
    
    private void processTypedMessage(final Message msg, final Integer type) {
        final String from = msg.getFrom();
        LOG.info("Processing typed message from {}", from);
        
        switch (type) {
            case (XmppMessageConstants.INFO_REQUEST_TYPE):
                LOG.info("Handling INFO request from {}", from);
                processInfoData(msg);
                sendInfoResponse(from);
                break;
            case (XmppMessageConstants.INFO_RESPONSE_TYPE):
                LOG.info("Handling INFO response from {}", from);
                processInfoData(msg);
                break;
            default:
                LOG.warn("Did not understand type: "+type);
                break;
        }
    }
    
    private void sendInfoResponse(final String from) {
        final Message msg = new Message();
        // The from becomes the to when we're responding.
        msg.setTo(from);
        msg.setProperty(P2PConstants.MESSAGE_TYPE, 
            XmppMessageConstants.INFO_RESPONSE_TYPE);
        msg.setProperty(P2PConstants.MAC, LanternUtils.getMacAddress());
        msg.setProperty(P2PConstants.CERT, 
            LanternHub.getKeyStoreManager().getBase64Cert());
        this.client.get().getXmppConnection().sendPacket(msg);
    }

    private void processInfoData(final Message msg) {
        LOG.info("Processing INFO data from request or response.");
        final URI uri;
        try {
            uri = new URI(msg.getFrom());
        } catch (final URISyntaxException e) {
            LOG.error("Could not create URI from: {}", msg.getFrom());
            return;
        }

        final String mac = (String) msg.getProperty(P2PConstants.MAC);
        final String base64Cert = (String) msg.getProperty(P2PConstants.CERT);
        LOG.info("Base 64 cert: {}", base64Cert);
        
        if (StringUtils.isNotBlank(base64Cert)) {
            LOG.info("Got certificate:\n"+
                new String(Base64.decodeBase64(base64Cert)));
            try {
                // Add the peer if we're able to add the cert.
                LanternHub.getKeyStoreManager().addBase64Cert(mac, base64Cert);
                if (LanternHub.settings().isAutoConnectToPeers()) {
                    final String email = XmppUtils.jidToUser(msg.getFrom());
                    if (this.roster.isFullyOnRoster(email)) {
                        LanternHub.trustedPeerProxyManager().onPeer(uri);
                    } else {
                        LanternHub.anonymousPeerProxyManager().onPeer(uri);
                    }
                    /*
                    if (LanternHub.getTrustedContactsManager().isTrusted(msg)) {
                        LanternHub.trustedPeerProxyManager().onPeer(uri);
                    } else {
                        LanternHub.anonymousPeerProxyManager().onPeer(uri);
                    }
                    */
                }
            } catch (final IOException e) {
                LOG.error("Could not add cert??", e);
            }
        } else {
            LOG.error("No cert for peer?");
        }
    }

    private void addProxy(final String cur) {
        LOG.info("Considering proxy: {}", cur);
        if (cur.contains("appspot")) {
            addLaeProxy(cur);
            return;
        }
        if (!cur.contains("@")) {
            addGeneralProxy(cur);
            return;
        }
        if (!isLoggedIn()) {
            LOG.info("Not connected -- ignoring proxy: {}", cur);
            return;
        }
        final String jid = 
            this.client.get().getXmppConnection().getUser().trim();
        
        final String emailId = XmppUtils.jidToUser(jid);
        LOG.info("We are: {}", jid);
        LOG.info("Service name: {}",
             this.client.get().getXmppConnection().getServiceName());
        if (jid.equals(cur.trim())) {
            LOG.info("Not adding ourselves as a proxy!!");
            return;
        }
        if (cur.startsWith(emailId+"/")) {
            try {
                addPeerProxy(new URI(cur));
            } catch (final URISyntaxException e) {
                LOG.error("Error with proxy URI", e);
            }
        } else if (cur.contains("@")) {
            try {
                addPeerProxy(new URI(cur));
            } catch (final URISyntaxException e) {
                LOG.error("Error with proxy URI", e);
            }
        } 
    }

    
    private void addPeerProxy(final URI peerUri) {
        LOG.info("Considering peer proxy");
        synchronized (peerProxySet) {
            // We purely do this to keep track of which peers we've attempted
            // to establish connections to. This is to avoid exchanging certs
            // multiple times.
            
            // TODO: I believe this excludes exchanging keys with peers who
            // are on multiple machines when the peer URI is a general JID and
            // not an instance JID.
            if (!peerProxySet.contains(peerUri)) {
                LOG.info("Actually adding peer proxy: {}", peerUri);
                peerProxySet.add(peerUri);
                sendAndRequestCert(peerUri);
            } else {
                LOG.info("We already know about the peer proxy");
            }
        }
    }
    
    private void sendAndRequestCert(final URI cur) {
        LOG.info("Requesting cert from {}", cur);
        final Message msg = new Message();
        msg.setProperty(P2PConstants.MESSAGE_TYPE, 
            XmppMessageConstants.INFO_REQUEST_TYPE);
        
        msg.setTo(cur.toASCIIString());
        // Set our certificate in the request as well -- we want to make
        // extra sure these get through!
        msg.setProperty(P2PConstants.MAC, LanternUtils.getMacAddress());
        msg.setProperty(P2PConstants.CERT, 
            LanternHub.getKeyStoreManager().getBase64Cert());
        this.client.get().getXmppConnection().sendPacket(msg);
    }

    private void addLaeProxy(final String cur) {
        LOG.info("Adding LAE proxy");
        addProxyWithChecks(this.laeProxySet, this.laeProxies, 
            new ProxyHolder(cur, new InetSocketAddress(cur, 443)), cur);
    }
    
    private void addGeneralProxy(final String cur) {
        final String hostname = StringUtils.substringBefore(cur, ":");
        final int port = Integer.parseInt(StringUtils.substringAfter(cur, ":"));
        final InetSocketAddress isa = new InetSocketAddress(hostname, port);
        addProxyWithChecks(proxySet, proxies, new ProxyHolder(hostname, isa), 
            cur);
    }

    private void addProxyWithChecks(final Set<ProxyHolder> set,
        final Queue<ProxyHolder> queue, final ProxyHolder ph, 
        final String fullProxyString) {
        if (set.contains(ph)) {
            LOG.info("We already know about proxy "+ph+" in {}", set);
            
            // Send the event again in case we've somehow gotten into the 
            // wrong state.
            LOG.info("Dispatching CONNECTED event");
            connectivityEvent(ConnectivityStatus.CONNECTED);
            return;
        }
        
        final Socket sock = new Socket();
        try {
            sock.connect(ph.isa, 60*1000);
            LOG.info("Dispatching CONNECTED event");
            connectivityEvent(ConnectivityStatus.CONNECTED);
            
            // This is a little odd because the proxy could have originally
            // come from the settings themselves, but it'll remove duplicates,
            // so no harm done.
            LanternHub.settings().addProxy(fullProxyString);
            synchronized (set) {
                if (!set.contains(ph)) {
                    set.add(ph);
                    queue.add(ph);
                    LOG.info("Queue is now: {}", queue);
                }
            }
        } catch (final IOException e) {
            LOG.error("Could not connect to: {}", ph);
            sendErrorMessage(ph.isa, e.getMessage());
            onCouldNotConnect(ph.isa);
            LanternHub.settings().removeProxy(fullProxyString);
        } finally {
            IOUtils.closeQuietly(sock);
        }
    }
    
    @Override
    public void onCouldNotConnect(final InetSocketAddress proxyAddress) {
        // This can happen in several scenarios. First, it can happen if you've
        // actually disconnected from the internet. Second, it can happen if
        // the proxy is blocked. Third, it can happen when the proxy is simply
        // down for some reason.
        LOG.info("COULD NOT CONNECT TO STANDARD PROXY!! Proxy address: {}", 
            proxyAddress);
        
        // For now we assume this is because we've lost our connection.
        //onCouldNotConnect(new ProxyHolder(proxyAddress.getHostName(), proxyAddress), 
        //    this.proxySet, this.proxies);
    }
    
    @Override
    public void onCouldNotConnectToLae(final InetSocketAddress proxyAddress) {
        LOG.info("COULD NOT CONNECT TO LAE PROXY!! Proxy address: {}", 
            proxyAddress);
        
        // For now we assume this is because we've lost our connection.
        
        //onCouldNotConnect(new ProxyHolder(proxyAddress.getHostName(), proxyAddress), 
        //    this.laeProxySet, this.laeProxies);
    }
    
    private void onCouldNotConnect(final ProxyHolder proxyAddress,
        final Set<ProxyHolder> set, final Queue<ProxyHolder> queue){
        LOG.info("COULD NOT CONNECT!! Proxy address: {}", proxyAddress);
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
        //if (LanternHub.getTrustedContactsManager().isJidTrusted(uri.toASCIIString())) {
            LanternHub.trustedPeerProxyManager().removePeer(uri);
        //} else {
        //    LanternHub.anonymousPeerProxyManager().removePeer(uri);
        //}
    }
    
    private void removePeerUri(final URI peerUri) {
        LOG.info("Removing peer with URI: {}", peerUri);
        //remove(peerUri, this.establishedPeerProxies);
    }

    private void removeAnonymousPeerUri(final URI peerUri) {
        LOG.info("Removing anonymous peer with URI: {}", peerUri);
        //remove(peerUri, this.establishedAnonymousProxies);
    }
    
    private void remove(final URI peerUri, final Queue<URI> queue) {
        LOG.info("Removing peer with URI: {}", peerUri);
        queue.remove(peerUri);
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
    public PeerProxyManager getAnonymousPeerProxyManager() {
        return LanternHub.anonymousPeerProxyManager();
    }
    
    
    @Override
    public PeerProxyManager getTrustedPeerProxyManager() {
        return LanternHub.trustedPeerProxyManager();
    }

    private InetSocketAddress getProxy(final Queue<ProxyHolder> queue) {
        synchronized (queue) {
            if (queue.isEmpty()) {
                LOG.info("No proxy addresses");
                return null;
            }
            final ProxyHolder proxy = queue.remove();
            queue.add(proxy);
            LOG.info("FIFO queue is now: {}", queue);
            return proxy.isa;
        }
    }

    @Override
    public XmppP2PClient getP2PClient() {
        return client.get();
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
    
    @Override
    public boolean isLoggedIn() {
        if (this.client.get() == null) {
            return false;
        }
        final XMPPConnection conn = client.get().getXmppConnection();
        if (conn == null) {
            return false;
        }
        return conn.isAuthenticated();
    }

    @Override
    public void sendInvite(final String email) {
        LOG.info("Sending invite");
        
        if (StringUtils.isBlank(this.hubAddress)) {
            LOG.error("Blank hub address when sending invite?");
            return;
        }
        
        final Set<String> invited = LanternHub.settings().getInvited();
        if (invited.contains(email)) {
            LOG.info("Already invited");
            return;
        }
        final XMPPConnection conn = this.client.get().getXmppConnection();
        final Roster rost = conn.getRoster();
        
        final Presence pres = new Presence(Presence.Type.available);
        pres.setTo(LanternConstants.LANTERN_JID);
        
        // "emails" of the form xxx@public.talk.google.com aren't really
        // e-mail addresses at all, so don't send 'em.
        // In theory we might be able to use the Google Plus API to get 
        // actual e-mail addresses -- see:
        // https://github.com/getlantern/lantern/issues/432
        if (email.contains("public.talk.google.com")) {
            pres.setProperty(LanternConstants.INVITED_EMAIL, "");
        } else {
            pres.setProperty(LanternConstants.INVITED_EMAIL, email);
        }
        
        final RosterEntry entry = rost.getEntry(email);
        if (entry != null) {
            final String name = entry.getName();
            if (StringUtils.isNotBlank(name)) {
                pres.setProperty(LanternConstants.INVITEE_NAME, name);
            }
        }
        
        
        try {
            final VCard vcard = PhotoServlet.getVCard(LanternUtils.toEmail(conn));
            if (vcard != null) {
                final String fullName = vcard.getField("FN");
                if (StringUtils.isNotBlank(fullName)) {
                    pres.setProperty(LanternConstants.INVITER_NAME, fullName);
                } else {
                    pres.setProperty(LanternConstants.INVITER_NAME, "");
                }
            }
        } catch (final CredentialException e) {
            LOG.warn("Bad credentials?", e);
        } catch (final XMPPException e) {
            LOG.warn("XMPP Error?", e);
        } catch (final IOException e) {
            LOG.warn("IO Error?", e);
        }
        invited.add(email);
        //pres.setProperty(LanternConstants.INVITER_NAME, value);
        
        final Runnable runner = new Runnable() {
            
            @Override
            public void run() {
                conn.sendPacket(pres);
            }
        };
        final Thread t = new Thread(runner, "Invite-Thread");
        t.setDaemon(true);
        t.start();
        LanternHub.settings().setInvites(LanternHub.settings().getInvites()-1);
        LanternHub.settingsIo().write();
        
        addToRoster(email);
    }
    
    @Override
    public void subscribe(final String jid) {
        LOG.info("Sending subscribe message to: {}", jid);
        sendTypedPacket(jid, Presence.Type.subscribe);
    }
    
    @Override
    public void subscribed(final String jid) {
        LOG.info("Sending subscribe message to: {}", jid);
        sendTypedPacket(jid, Presence.Type.subscribed);
        roster.removeIncomingSubscriptionRequest(jid);
    }
    
    @Override
    public void unsubscribe(final String jid) {
        LOG.info("Sending unsubscribe message to: {}", jid);
        sendTypedPacket(jid, Presence.Type.unsubscribe);
    }
    
    @Override
    public void unsubscribed(final String jid) {
        LOG.info("Sending unsubscribed message to: {}", jid);
        sendTypedPacket(jid, Presence.Type.unsubscribed);
        roster.removeIncomingSubscriptionRequest(jid);
    }
    
    private void sendTypedPacket(final String jid, final Type type) {
        final Presence packet = new Presence(type);
        packet.setTo(jid);
        final XMPPConnection conn = this.client.get().getXmppConnection();
        //packet.setFrom(XmppUtils.jidToUser(conn));
        //packet.setFrom(conn.getUser());
        conn.sendPacket(packet);
    }
    
    @Override
    public void addToRoster(final String email) {
        // If the user is not already on our roster, we want to make sure to
        // send them an invite. If the e-mail address specified does not 
        // correspond with a Jabber ID, then we're out of luck. If it does,
        // then this will send the roster invite.
        final XMPPConnection conn = this.client.get().getXmppConnection();
        final Roster rost = conn.getRoster();
        final RosterEntry entry = rost.getEntry(email);
        if (entry == null) {
            LOG.info("Inviting user to join roster: {}", email);
            try {
                // Note this also sends a subscription request!!
                rost.createEntry(email, 
                    StringUtils.substringBefore(email, "@"), new String[]{});
            } catch (final XMPPException e) {
                LOG.error("Could not create entry?", e);
            }
        }
    }

    @Override
    public void removeFromRoster(final String email) {
        final XMPPConnection conn = this.client.get().getXmppConnection();
        final Roster rost = conn.getRoster();
        final RosterEntry entry = rost.getEntry(email);
        if (entry != null) {
            LOG.info("Removing user from roster: {}", email);
            try {
                rost.removeEntry(entry);
            } catch (final XMPPException e) {
                LOG.error("Could not create entry?", e);
            }
        }
    }
    

    private final Object rosterLock = new Object();

    /**
     * This is primarily here because the frontend can request the roster 
     * before we have it. We block until the roster comes in.
     */
    private void waitForRoster() {
        synchronized (rosterLock) {
            while(!this.roster.populated()) {
                try {
                    rosterLock.wait(40000);
                } catch (final InterruptedException e) {
                }
            }
        }
    }

    @Override
    public org.lantern.Roster getRoster() {
        if (this.roster == null) {
            waitForRoster();
        }
        return this.roster;
    }
    
    @Override
    public void resetRoster() {
        this.roster.reset();;
    }

    @Override
    public String getLastUserName() {
        return lastUserName;
    }

    @Override
    public String getLastPass() {
        return lastPass;
    }
    
    
    private void setupJmx() {
        final MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
        try {
            final Class<? extends Object> clazz = getClass();
            final String pack = clazz.getPackage().getName();
            final String oName =
                pack+":type="+clazz.getSimpleName()+"-"+clazz.getSimpleName();
            LOG.info("Registering MBean with name: {}", oName);
            final ObjectName mxBeanName = new ObjectName(oName);
            if(!mbs.isRegistered(mxBeanName)) {
                mbs.registerMBean(this, mxBeanName);
            }
        } catch (final MalformedObjectNameException e) {
            LOG.error("Could not set up JMX", e);
        } catch (final InstanceAlreadyExistsException e) {
            LOG.error("Could not set up JMX", e);
        } catch (final MBeanRegistrationException e) {
            LOG.error("Could not set up JMX", e);
        } catch (final NotCompliantMBeanException e) {
            LOG.error("Could not set up JMX", e);
        }
    }
    
    @Override
    public void stop() {
        LOG.info("Stopping XMPP handler...");
        disconnect();
        if (upnpService != null) {
            upnpService.shutdown();
        }
        if (natPmpService != null) {
            natPmpService.shutdown();
        }
        LOG.info("Finished stoppeding XMPP handler...");
    }
}
