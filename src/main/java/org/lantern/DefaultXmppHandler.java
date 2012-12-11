package org.lantern;

import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.atomic.AtomicReference;

import javax.management.InstanceAlreadyExistsException;
import javax.management.MBeanRegistrationException;
import javax.management.MBeanServer;
import javax.management.MalformedObjectNameException;
import javax.management.NotCompliantMBeanException;
import javax.management.ObjectName;
import javax.security.auth.login.CredentialException;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
import org.codehaus.jackson.JsonParseException;
import org.codehaus.jackson.map.JsonMappingException;
import org.codehaus.jackson.map.ObjectMapper;
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
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.kaleidoscope.BasicTrustGraphAdvertisement;
import org.kaleidoscope.BasicTrustGraphNodeId;
import org.kaleidoscope.TrustGraphNode;
import org.kaleidoscope.TrustGraphNodeId;
import org.lantern.event.ClosedBetaEvent;
import org.lantern.event.Events;
import org.lantern.event.GoogleTalkStateEvent;
import org.lantern.event.ResetEvent;
import org.lantern.event.UpdateEvent;
import org.lantern.event.UpdatePresenceEvent;
import org.lantern.ksope.LanternKscopeAdvertisement;
import org.lantern.ksope.LanternTrustGraphNode;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;
import org.lantern.state.ModelUtils;
import org.lantern.state.Profile;
import org.lastbamboo.common.ice.MappedServerSocket;
import org.lastbamboo.common.ice.MappedTcpAnswererServer;
import org.lastbamboo.common.p2p.P2PConnectionEvent;
import org.lastbamboo.common.p2p.P2PConnectionListener;
import org.lastbamboo.common.p2p.P2PConstants;
import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.lastbamboo.common.portmapping.UpnpService;
import org.lastbamboo.common.stun.client.PublicIpAddress;
import org.lastbamboo.common.stun.client.StunServerRepository;
import org.littleshoot.commom.xmpp.PasswordCredentials;
import org.littleshoot.commom.xmpp.XmppCredentials;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.littleshoot.p2p.P2P;
import org.littleshoot.util.SessionSocketListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;
import com.hoodcomputing.natpmp.NatPmpException;

/**
 * Handles logging in to the XMPP server and processing trusted users through
 * the roster.
 */
@Singleton
public class DefaultXmppHandler implements XmppHandler {
    
    private static final Logger LOG = 
        LoggerFactory.getLogger(DefaultXmppHandler.class);
    
    private final AtomicReference<XmppP2PClient> client = 
        new AtomicReference<XmppP2PClient>();
    
    static {
        SmackConfiguration.setPacketReplyTimeout(30 * 1000);
    }

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

    private GoogleTalkState state;

    private String lastUserName;

    private String lastPass;

    private NatPmpService natPmpService;

    private final UpnpService upnpService;

    private ClosedBetaEvent closedBetaEvent;
    
    private final Object closedBetaLock = new Object();

    private MappedServerSocket mappedServer;

    private final PeerProxyManager trustedPeerProxyManager;

    private final PeerProxyManager anonymousPeerProxyManager;

    private final Timer timer;

    private final Stats stats;

    private final LanternKeyStoreManager keyStoreManager;

    private final LanternSocketsUtil socketsUtil;

    private final LanternXmppUtil xmppUtil;

    private final Model model;

    private volatile boolean started;

    private final ModelUtils modelUtils;

    private final ModelIo modelIo;

    private final org.lantern.Roster roster;

    private final ProxyTracker proxyTracker;

    private final Censored censored;

    /**
     * Creates a new XMPP handler.
     */
    @Inject
    public DefaultXmppHandler(final Model model,
        final TrustedPeerProxyManager trustedPeerProxyManager,
        final AnonymousPeerProxyManager anonymousPeerProxyManager,
        final Timer updateTimer, final Stats stats,
        final LanternKeyStoreManager keyStoreManager,
        final LanternSocketsUtil socketsUtil,
        final LanternXmppUtil xmppUtil,
        final ModelUtils modelUtils,
        final ModelIo modelIo, final org.lantern.Roster roster,
        final ProxyTracker proxyTracker,
        final Censored censored) {
        this.model = model;
        this.trustedPeerProxyManager = trustedPeerProxyManager;
        this.anonymousPeerProxyManager = anonymousPeerProxyManager;
        this.timer = updateTimer;
        this.stats = stats;
        this.keyStoreManager = keyStoreManager;
        this.socketsUtil = socketsUtil;
        this.xmppUtil = xmppUtil;
        this.modelUtils = modelUtils;
        this.modelIo = modelIo;
        this.roster = roster;
        this.proxyTracker = proxyTracker;
        this.censored = censored;
        this.upnpService = new Upnp(stats);
        new GiveModeConnectivityHandler();
        prepopulateProxies();
        Events.register(this);
        //setupJmx();
    }
   

    @Override
    public void start() {
        // This just links connectivity with Google Talk login status when 
        // running in give mode.
        NatPmpService temp = null;
        try {
            temp = new NatPmp(stats);
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
        
        MappedServerSocket tempMapper;
        try {
            LOG.debug("Creating mapped TCP server...");
            tempMapper =
                new MappedTcpAnswererServer(natPmpService, upnpService, 
                    new InetSocketAddress(this.model.getSettings().getServerPort()));
            LOG.debug("Created mapped TCP server...");
        } catch (final IOException e) {
            LOG.info("Exception mapping TCP server", e);
            tempMapper = new MappedServerSocket() {
                
                @Override
                public boolean isPortMapped() {
                    return false;
                }
                
                @Override
                public int getMappedPort() {
                    return 1;
                }
                
                @Override
                public InetSocketAddress getHostAddress() {
                    return new InetSocketAddress(getMappedPort());
                }
            };
        }
        
        XmppUtils.setGlobalConfig(this.xmppUtil.xmppConfig());
        XmppUtils.setGlobalProxyConfig(this.xmppUtil.xmppProxyConfig());
        
        this.mappedServer = tempMapper;
        this.started = true;
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
    
    @Subscribe
    public void onAuthStatus(final GoogleTalkStateEvent ase) {
        this.state = ase.getState();
        switch (state) {
        case connected:
            // We wait until we're logged in before creating our roster.
            final XMPPConnection conn = getP2PClient().getXmppConnection();
            final org.jivesoftware.smack.Roster ros = conn.getRoster();
            this.roster.onRoster(ros);
            break;
        case notConnected:
            this.roster.reset();
            break;
        case connecting:
            break;
        case LOGIN_FAILED:
            this.roster.reset();
            break;
        }
    }
    
    private void prepopulateProxies() {
        // Add all the stored proxies.
        final Collection<String> saved = this.model.getSettings().getProxies();
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
        if (!this.started) {
            LOG.warn("Can't connect when not started!!");
            throw new Error("Can't connect when not started!!");
        }
        if (!this.modelUtils.isConfigured()) {
            if (this.model.getSettings().isUiEnabled()) {
                LOG.info("Not connecting when not configured and UI enabled");
                return;
            }
        }
        LOG.info("Connecting to XMPP servers...");
        if (this.model.getSettings().isUseGoogleOAuth2()) {
            connectViaOAuth2();
        } else {
            //connectWithEmailAndPass();
            throw new Error("Oauth not configured properly?");
        }
    }

    private void connectViaOAuth2() throws IOException,
            CredentialException, NotInClosedBetaException {
        final XmppCredentials credentials = 
            this.modelUtils.newGoogleOauthCreds(getResource());
        
        LOG.info("Logging in with credentials: {}", credentials);
        connect(credentials);
    }

    /*
    private void connectWithEmailAndPass() throws IOException,
            CredentialException, NotInClosedBetaException {
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
    */
    
    @Override
    public void connect(final String email, final String pass) 
        throws IOException, CredentialException, NotInClosedBetaException {
        this.lastUserName = email;
        this.lastPass = pass;
        connect(new PasswordCredentials(email, pass, getResource()));
    }

    private String getResource() {
        if (model.getSettings().isGetMode()) {
            LOG.info("Setting ID for get mode...");
            return "gmail.";
        } else {
            LOG.info("Setting ID for give mode");
            return LanternConstants.UNCENSORED_ID;
        }
    }

    public void connect(final XmppCredentials credentials)
        throws IOException, CredentialException, NotInClosedBetaException {
        LOG.debug("Connecting to XMPP servers with user name and password...");
        this.closedBetaEvent = null;
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
            upnpService, this.mappedServer, 
            //newTlsSocketFactory(),ç SSLServerSocketFactory.getDefault(),//newTlsServerSocketFactory(),
            this.socketsUtil.newTlsSocketFactory(), this.socketsUtil.newTlsServerSocketFactory(),
            //SocketFactory.getDefault(), ServerSocketFactory.getDefault(), 
            plainTextProxyRelayAddress, sessionListener, false));
        
        this.client.get().addConnectionListener(new P2PConnectionListener() {
            
            @Override
            public void onConnectivityEvent(final P2PConnectionEvent event) {
                LOG.debug("Got connectivity event: {}", event);
                Events.asyncEventBus().post(event);
            }
        });
        
        // This is a global, backup listener added to the client. We might
        // get notifications of messages twice in some cases, but that's
        // better than the alternative of sometimes not being notified
        // at all.
        LOG.debug("Adding message listener...");
        this.client.get().addMessageListener(typedListener);
        
        Events.eventBus().post(
            new GoogleTalkStateEvent(GoogleTalkState.connecting));

        try {
            this.client.get().login(credentials);
            LOG.debug("Sending connected event");
            Events.eventBus().post(
                new GoogleTalkStateEvent(GoogleTalkState.connected));
        } catch (final IOException e) {
            // Note that the XMPP library will internally attempt to connect
            // to our backup proxy if it can.
            handleConnectionFailure();
            throw e;
        } catch (final IllegalStateException e) {
            handleConnectionFailure();
            throw e;
        } catch (final CredentialException e) {
            handleConnectionFailure();
            throw e;
        }
        
        // Note we don't consider ourselves connected in get mode until we 
        // actually get proxies to work with.
        final XMPPConnection connection = this.client.get().getXmppConnection();
        final Collection<String> servers = 
                this.model.getSettings().getStunServers();
        if (servers.isEmpty()) {
            final Collection<InetSocketAddress> googleStunServers = 
                    XmppUtils.googleStunServers(connection);
            StunServerRepository.setStunServers(googleStunServers);
            this.model.getSettings().setStunServers(
                    new HashSet<String>(toStringServers(googleStunServers)));
        }
        
        // Make sure all connections between us and the server are stored
        // OTR.
        LanternUtils.activateOtr(connection);
        
        LOG.debug("Connection ID: {}", connection.getConnectionID());
        
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
                        
                        final boolean isLantern =
                            LanternUtils.isLanternMessage(pres);
                        // If we get a subscription request from someone 
                        // already on our roster, auto-accept it.
                        if (isLantern) {
                            if (roster.autoAcceptSubscription(from)) {
                                subscribed(from);
                            }
                            roster.addIncomingSubscriptionRequest(pres);
                        }
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

        final boolean inClosedBeta = waitForClosedBetaStatus(credentials.getUsername());

        // If we're in the closed beta and are an uncensored node, we want to
        // advertise ourselves through the kaleidoscope trust network.
        if (inClosedBeta && !censored.isCensored()) {
            final TimerTask tt = new TimerTask() {
                
                @Override
                public void run() {
                    final TrustGraphNodeId tgnid = new BasicTrustGraphNodeId(
                        model.getNodeId());
                    
                    final InetAddress address = 
                        new PublicIpAddress().getPublicIpAddress();
                    
                    final String user = connection.getUser();
                    // The payload here is JSON with everything from the 
                    // JID of the user to the public IP address and port
                    // that should be mapped on the user's router.
                    final LanternKscopeAdvertisement ad;
                    if (mappedServer.isPortMapped()) {
                        ad = new LanternKscopeAdvertisement(user, address, 
                            mappedServer.getMappedPort());
                    } else {
                        ad = new LanternKscopeAdvertisement(user);
                    }
                    
                    // Now turn the advertisement into JSON.
                    final String payload = LanternUtils.jsonify(ad);
                    
                    LOG.info("Sending kscope payload: {}", payload);
                    final BasicTrustGraphAdvertisement message =
                        new BasicTrustGraphAdvertisement(tgnid, payload, 0);
                    
                    final TrustGraphNode tgn = 
                        new LanternTrustGraphNode(DefaultXmppHandler.this);
                    tgn.advertiseSelf(message);
                }
            };
            // We delay this to make sure we've successfully loaded all roster
            // updates and presence notifications before sending out our
            // advertisement.
            this.timer.schedule(tt, 30000);
        }
    }
  
    private void handleConnectionFailure() {
        Events.eventBus().post(
            new GoogleTalkStateEvent(GoogleTalkState.LOGIN_FAILED));
    }

    private boolean waitForClosedBetaStatus(final String email) 
        throws NotInClosedBetaException {
        if (this.modelUtils.isInClosedBeta(email)) {
            LOG.debug("Already in closed beta...");
            return true;
        }
        
        // The following is necessary because the call to login needs to either
        // succeed or fail for the UI to work properly, but we don't know if
        // a user is able to log in until we get an asynchronous XMPP message
        // back from the server.
        synchronized (this.closedBetaLock) {
            if (this.closedBetaEvent == null) {
                try {
                    this.closedBetaLock.wait(80 * 1000);
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
                return true;
            }
        } else {
            LOG.warn("No closed beta event -- timed out!!");
            notInClosedBeta("No closed beta event!!");
        }
        return false;
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
    
    @Override
    public void disconnect() {
        LOG.info("Disconnecting!!");
        lastJson = "";
        /*
        LanternHub.eventBus().post(
            new GoogleTalkStateEvent(GoogleTalkState.LOGGING_OUT));
        */
        
        final XmppP2PClient cl = this.client.get();
        if (cl != null) {
            this.client.get().logout();
            this.client.set(null);
        }

        Events.eventBus().post(
            new GoogleTalkStateEvent(GoogleTalkState.notConnected));
        
        proxyTracker.clearPeerProxySet();
        this.closedBetaEvent = null;
        
        // This is mostly logged for debugging thorny shutdown issues...
        LOG.info("Finished disconnecting XMPP...");
    }

    private void processLanternHubMessage(final Message msg) {
        LOG.debug("Lantern controlling agent response");
        this.hubAddress = msg.getFrom();
        final String to = XmppUtils.jidToUser(msg.getTo());
        LOG.debug("Set hub address to: {}", hubAddress);
        final String body = msg.getBody();
        LOG.debug("Body: {}", body);
        final Object obj = JSONValue.parse(body);
        final JSONObject json = (JSONObject) obj;
        
        final Boolean inClosedBeta = 
            (Boolean) json.get(LanternConstants.INVITED);
        
        if (inClosedBeta != null) {
            Events.asyncEventBus().post(new ClosedBetaEvent(to, inClosedBeta));
            if (!inClosedBeta) {
                //return;
            }
        } else {
            Events.asyncEventBus().post(new ClosedBetaEvent(to, false));
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
                timer.schedule(new TimerTask() {
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
            final Map<String, Object> event = 
                new HashMap<String, Object>();
            event.putAll(update);
            Events.asyncEventBus().post(new UpdateEvent(event));
        }
        
        final Long invites = 
            (Long) json.get(LanternConstants.INVITES_KEY);
        if (invites != null) {
            LOG.info("Setting invites to: {}", invites);
            this.model.setNinvites(invites.intValue());
        }
    }
    
    @Subscribe
    public void onClosedBetaEvent(final ClosedBetaEvent cbe) {
        LOG.debug("Got closed beta event!!");
        this.closedBetaEvent = cbe;
        if (this.closedBetaEvent.isInClosedBeta()) {
            this.modelUtils.addToClosedBeta(cbe.getTo());
        }
        synchronized (this.closedBetaLock) {
            // We have to make sure that this event is actually intended for
            // the user we're currently logged in as!
            final String to = this.closedBetaEvent.getTo();
            LOG.debug("Analyzing closed beta event for: {}", to);
            if (isLoggedIn()) {
                final String user = LanternUtils.toEmail(
                    this.client.get().getXmppConnection());
                if (user.equals(to)) {
                    LOG.debug("Users match!");
                    this.closedBetaLock.notifyAll();
                } else {
                    LOG.debug("Users don't match {}, {}", user, to);
                }
            }
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
            final String str = LanternUtils.jsonify(stats);
            LOG.debug("Reporting data: {}", str);
            if (!this.lastJson.equals(str)) {
                this.lastJson = str;
                forHub.setProperty("stats", str);
                stats.resetCumulativeStats();
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
    

    private void addPeerProxy(final URI peerUri) {
        if (this.proxyTracker.addPeerProxy(peerUri)) {
            sendAndRequestCert(peerUri);
        }
    }
    
    @Subscribe
    public void onUpdatePresenceEvent(final UpdatePresenceEvent upe) {
        // This was originally added to decouple the roster from this class.
        final Presence pres = upe.getPresence();
        addOrRemovePeer(pres, pres.getFrom());
    }

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
            this.proxyTracker.removePeer(uri);
        }
    }
    
    private void processTypedMessage(final Message msg, final Integer type) {
        final String from = msg.getFrom();
        LOG.info("Processing typed message from {}", from);
        
        switch (type) {
            case (XmppMessageConstants.INFO_REQUEST_TYPE):
                LOG.debug("Handling INFO request from {}", from);
                processInfoData(msg);
                sendInfoResponse(from);
                break;
            case (XmppMessageConstants.INFO_RESPONSE_TYPE):
                LOG.debug("Handling INFO response from {}", from);
                processInfoData(msg);
                break;
                
            case (LanternConstants.KSCOPE_ADVERTISEMENT):
                LOG.debug("Handling KSCOPE ADVERTISEMENT");
                final String payload = 
                    (String) msg.getProperty(
                        LanternConstants.KSCOPE_ADVERTISEMENT_KEY);
                if (StringUtils.isNotBlank(payload)) {
                    processKscopePayload(payload);
                } else {
                    LOG.error("kscope ad with no payload? "+msg.toXML());
                }
                break;
            default:
                LOG.warn("Did not understand type: "+type);
                break;
        }
    }
    
    private void processKscopePayload(final String payload) {
        final ObjectMapper mapper = new ObjectMapper();
        try {
            final LanternKscopeAdvertisement ad = 
                mapper.readValue(payload, LanternKscopeAdvertisement.class);
            
            // If the ad includes a mapped port, include it as straight proxy.
            if (ad.hasMappedEndpoint()) {
                final String proxy = ad.getAddress() + ":" + ad.getPort();
                this.proxyTracker.addGeneralProxy(proxy);
            }
            addPeerProxy(new URI(ad.getJid()));
            
        } catch (final JsonParseException e) {
            LOG.warn("Could not parse JSON", e);
        } catch (final JsonMappingException e) {
            LOG.warn("Could not map JSON", e);
        } catch (final IOException e) {
            LOG.warn("IO error parsing JSON", e);
        } catch (final URISyntaxException e) {
            LOG.error("Syntax exception with URI?", e);
        }
    }

    private void sendInfoResponse(final String from) {
        final Message msg = new Message();
        // The from becomes the to when we're responding.
        msg.setTo(from);
        msg.setProperty(P2PConstants.MESSAGE_TYPE, 
            XmppMessageConstants.INFO_RESPONSE_TYPE);
        msg.setProperty(P2PConstants.MAC, LanternUtils.getMacAddress());
        msg.setProperty(P2PConstants.CERT, this.keyStoreManager.getBase64Cert());
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
                this.keyStoreManager.addBase64Cert(mac, base64Cert);
                if (this.model.getSettings().isAutoConnectToPeers()) {
                    final String email = XmppUtils.jidToUser(msg.getFrom());
                    if (this.roster.isFullyOnRoster(email)) {
                        trustedPeerProxyManager.onPeer(uri);
                    } else {
                        anonymousPeerProxyManager.onPeer(uri);
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
            this.proxyTracker.addLaeProxy(cur);
            return;
        }
        if (!cur.contains("@")) {
            this.proxyTracker.addGeneralProxy(cur);
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

    private void sendAndRequestCert(final URI cur) {
        LOG.info("Requesting cert from {}", cur);
        final Message msg = new Message();
        msg.setProperty(P2PConstants.MESSAGE_TYPE, 
            XmppMessageConstants.INFO_REQUEST_TYPE);
        
        msg.setTo(cur.toASCIIString());
        // Set our certificate in the request as well -- we want to make
        // extra sure these get through!
        msg.setProperty(P2PConstants.MAC, LanternUtils.getMacAddress());
        msg.setProperty(P2PConstants.CERT, this.keyStoreManager.getBase64Cert());
        this.client.get().getXmppConnection().sendPacket(msg);
    }
    
    /*
    @Override
    public PeerProxyManager getAnonymousPeerProxyManager() {
        return LanternHub.anonymousPeerProxyManager();
    }
    
    
    @Override
    public PeerProxyManager getTrustedPeerProxyManager() {
        return LanternHub.trustedPeerProxyManager();
    }
    */

    @Override
    public XmppP2PClient getP2PClient() {
        return client.get();
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
        
        final Set<String> invited = roster.getInvited();
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
        if (LanternUtils.isNotJid(email)) {
            pres.setProperty(LanternConstants.INVITED_EMAIL, email);
        } else {
            pres.setProperty(LanternConstants.INVITED_EMAIL, "");
        }
        
        final RosterEntry entry = rost.getEntry(email);
        if (entry != null) {
            final String name = entry.getName();
            if (StringUtils.isNotBlank(name)) {
                pres.setProperty(LanternConstants.INVITEE_NAME, name);
            }
        }
        
        final Profile prof = this.model.getProfile();
        pres.setProperty(LanternConstants.INVITER_NAME, prof.getName());
        
        final String json = LanternUtils.jsonify(prof);
        pres.setProperty(XmppMessageConstants.PROFILE, json);

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
        this.model.setNinvites(this.model.getNinvites() - 1);
        this.modelIo.write();
        //LanternHub.settings().setInvites(LanternHub.settings().getInvites()-1);
        //LanternHub.settingsIo().write();
        
        addToRoster(email);
    }
    
    @Override
    public void subscribe(final String jid) {
        LOG.info("Sending subscribe message to: {}", jid);
        final Presence packet = new Presence(Presence.Type.subscribe);
        packet.setTo(jid);
        final String json = LanternUtils.jsonify(this.model.getProfile());
        packet.setProperty(XmppMessageConstants.PROFILE, json);
        final XMPPConnection conn = this.client.get().getXmppConnection();
        conn.sendPacket(packet);
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
    
    @Subscribe
    public void onReset(final ResetEvent event) {
        disconnect();
    }
}
