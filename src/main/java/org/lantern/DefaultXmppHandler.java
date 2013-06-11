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
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.ExecutorService;
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
import org.jivesoftware.smack.filter.IQTypeFilter;
import org.jivesoftware.smack.filter.PacketFilter;
import org.jivesoftware.smack.packet.IQ;
import org.jivesoftware.smack.packet.Message;
import org.jivesoftware.smack.packet.Packet;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smack.packet.Presence.Type;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.lantern.event.ClosedBetaEvent;
import org.lantern.event.Events;
import org.lantern.event.GoogleTalkStateEvent;
import org.lantern.event.ResetEvent;
import org.lantern.event.UpdateEvent;
import org.lantern.event.UpdatePresenceEvent;
import org.lantern.kscope.KscopeAdHandler;
import org.lantern.kscope.LanternKscopeAdvertisement;
import org.lantern.state.Connectivity;
import org.lantern.state.Friend;
import org.lantern.state.Friend.Status;
import org.lantern.state.Friends;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;
import org.lantern.state.Notification.MessageType;
import org.lantern.state.SyncPath;
import org.lantern.udtrelay.UdtRelayServerFiveTupleListener;
import org.lantern.util.Threads;
import org.lastbamboo.common.ice.MappedServerSocket;
import org.lastbamboo.common.p2p.P2PConnectionEvent;
import org.lastbamboo.common.p2p.P2PConnectionListener;
import org.lastbamboo.common.p2p.P2PConstants;
import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.UpnpService;
import org.lastbamboo.common.stun.client.StunServerRepository;
import org.littleshoot.commom.xmpp.XmppCredentials;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.littleshoot.p2p.P2PEndpoints;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.SessionSocketListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Handles logging in to the XMPP server and processing trusted users through
 * the roster.
 */
@Singleton
public class DefaultXmppHandler implements XmppHandler {

    private static final Logger LOG =
        LoggerFactory.getLogger(DefaultXmppHandler.class);

    private final AtomicReference<XmppP2PClient<FiveTuple>> client =
        new AtomicReference<XmppP2PClient<FiveTuple>>();

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
            final String from = msg.getFrom();
            LOG.debug("Got chat participant: {} with message:\n {}", from,
                msg.toXML());
            if (msg.getType() == org.jivesoftware.smack.packet.Message.Type.error) {
                LOG.warn("Received error message!! {}", msg.toXML());
                return;
            }
            if (LanternUtils.isLanternHub(from)) {
                processLanternHubMessage(msg);
            }

            final Integer type =
                (Integer) msg.getProperty(P2PConstants.MESSAGE_TYPE);
            if (type != null) {
                LOG.debug("Processing typed message");
                processTypedMessage(msg, type);
            }
        }
    };

    private String lastJson = "";

    private String hubAddress;

    private GoogleTalkState state;

    private final NatPmpService natPmpService;

    private final UpnpService upnpService;

    private ClosedBetaEvent closedBetaEvent;

    private final Object closedBetaLock = new Object();

    private MappedServerSocket mappedServer;

    //private final PeerProxyManager trustedPeerProxyManager;

    private final Timer timer;

    private final Stats stats;

    private final LanternKeyStoreManager keyStoreManager;

    private final LanternSocketsUtil socketsUtil;

    private final LanternXmppUtil xmppUtil;

    private final Model model;

    private volatile boolean started;

    private final ModelUtils modelUtils;

    private final org.lantern.Roster roster;

    private final ProxyTracker proxyTracker;

    private final KscopeAdHandler kscopeAdHandler;

    private TimerTask reconnectIfNoPong;

    /**
     * The XMPP message id that we are waiting for a pong on
     */
    private String waitingForPong;

    private long pingTimeout = 15 * 1000;

    protected XMPPConnection previousConnection;

    private final ExecutorService xmppProcessors =
        Threads.newCachedThreadPool("Smack-XMPP-Message-Processing-");

    /**
     * Creates a new XMPP handler.
     */
    @Inject
    public DefaultXmppHandler(final Model model,
        //final PeerProxyManager trustedPeerProxyManager,
        final Timer updateTimer, final Stats stats,
        final LanternKeyStoreManager keyStoreManager,
        final LanternSocketsUtil socketsUtil,
        final LanternXmppUtil xmppUtil,
        final ModelUtils modelUtils,
        final org.lantern.Roster roster,
        final ProxyTracker proxyTracker,
        final KscopeAdHandler kscopeAdHandler,
        final NatPmpService natPmpService,
        final UpnpService upnpService) {
        this.model = model;
        this.timer = updateTimer;
        this.stats = stats;
        this.keyStoreManager = keyStoreManager;
        this.socketsUtil = socketsUtil;
        this.xmppUtil = xmppUtil;
        this.modelUtils = modelUtils;
        this.roster = roster;
        this.proxyTracker = proxyTracker;
        this.kscopeAdHandler = kscopeAdHandler;
        this.natPmpService = natPmpService;
        this.upnpService = upnpService;
        Events.register(this);
        //setupJmx();
    }

    @Override
    public MappedServerSocket getMappedServer() {
        return mappedServer;
    }

    @Override
    public void start() {
        this.modelUtils.loadClientSecrets();

        XmppUtils.setGlobalConfig(this.xmppUtil.xmppConfig());
        XmppUtils.setGlobalProxyConfig(this.xmppUtil.xmppProxyConfig());

        this.mappedServer = new LanternMappedTcpAnswererServer(natPmpService,
            upnpService, new InetSocketAddress(this.model.getSettings().getServerPort()));
        this.started = true;
    }

    @Override
    public void stop() {
        LOG.debug("Stopping XMPP handler...");
        disconnect();
        if (upnpService != null) {
            upnpService.shutdown();
        }
        if (natPmpService != null) {
            natPmpService.shutdown();
        }
        LOG.debug("Finished stoppeding XMPP handler...");
    }

    @Subscribe
    public void onAuthStatus(final GoogleTalkStateEvent ase) {
        this.state = ase.getState();
        switch (state) {
        case connected:
            // We wait until we're logged in before creating our roster.
            final XmppP2PClient<FiveTuple> cl = client.get();
            if (cl == null) {
                LOG.error("Null client for instance: "+hashCode());
                return;
            }
            this.roster.onRoster(this);
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

    @Subscribe
    public void onConnectivityChanged(final ConnectivityChangedEvent e) {
        if (!e.isConnected()) {
            // send a ping message to determine if we need to reconnect; failed
            // STUN connectivity is not necessarily a death sentence for the
            // XMPP connection.
            // If the ping fails, then XmppP2PClient will retry that connection
            // in a loop.
            ping();
            return;
        }
        LOG.info("Connected to internet: {}", e);
        LOG.info("Logged in? {}", this.isLoggedIn());
        XmppP2PClient<FiveTuple> client = this.client.get();
        if (client == null) {
            LOG.debug("No client?");
            return; //this is probably at startup
        }

        final XMPPConnection conn = client.getXmppConnection();
        if (e.isIpChanged()) {
            //definitely need to reconnect here
            reconnect();
        } else {
            if (conn == null || !conn.isConnected()) {
                //definitely need to reconnect here
                reconnect();
            } else {
                ping();
            }
        }
    }

    private void ping() {
        //if we are already pinging, cancel the existing ping
        //and retry
        if (reconnectIfNoPong != null) {
            reconnectIfNoPong.cancel();
        }

        XmppP2PClient<FiveTuple> client = this.client.get();
        if (client == null) {
            //no connection yet, so we'll just return; the connection
            //will be established when we can
            return;
        }
        XMPPConnection connection = client.getXmppConnection();
        IQ ping = new IQ() {
            @Override
            public String getChildElementXML() {
                return "<ping xmlns='urn:xmpp:ping'/>";
            }

        };
        waitingForPong = ping.getPacketID();
        //set up timer to reconnect if we don't hear a pong
        reconnectIfNoPong = new Reconnector();
        timer.schedule(reconnectIfNoPong, getPingTimeout());
        //and send the ping
        connection.sendPacket(ping);
    }

    /**
     * How long we wait,
     * @return
     */
    public long getPingTimeout() {
        return pingTimeout;
    }

    public void setPingTimeout(long pingTimeout) {
        this.pingTimeout = pingTimeout;
    }

    /**
     * This will be cancelled if a pong is received,
     * indicating that we have already successfully
     * reconnected
     */

    private class Reconnector extends TimerTask {
        @Override
        public void run() {
            reconnect();
        }
    }

    @Override
    public synchronized void connect() throws IOException, CredentialException,
        NotInClosedBetaException {
        if (!this.started) {
            LOG.warn("Can't connect when not started!!");
            throw new Error("Can't connect when not started!!");
        }
        if (!this.modelUtils.isConfigured()) {
            if (this.model.getSettings().isUiEnabled()) {
                LOG.debug("Not connecting when not configured and UI enabled");
                return;
            }
        }
        if (isLoggedIn()) {
            LOG.warn("Already logged in!! Not connecting");
            return;
        }
        LOG.debug("Connecting to XMPP servers...");
        if (this.modelUtils.isOauthConfigured()) {
            connectViaOAuth2();
        } else {
            throw new Error("Oauth not configured properly?");
        }
    }

    private void connectViaOAuth2() throws IOException,
            CredentialException, NotInClosedBetaException {
        final XmppCredentials credentials =
            this.modelUtils.newGoogleOauthCreds(getResource());

        LOG.debug("Logging in with credentials: {}", credentials);
        connect(credentials);
    }

    @Override
    public void connect(final String email, final String pass)
        throws IOException, CredentialException, NotInClosedBetaException {
        //connect(new PasswordCredentials(email, pass, getResource()));
    }

    private String getResource() {
        return LanternConstants.UNCENSORED_ID;
    }

    /** listen to responses for XMPP pings, and if we get any,
    cancel pending reconnects
    */
    private class PingListener implements PacketListener {
        @Override
        public void processPacket(Packet packet) {
            IQ iq = (IQ) packet;
            if (iq.getPacketID().equals(waitingForPong)) {
                LOG.debug("Got pong, cancelling pending reconnect");
                reconnectIfNoPong.cancel();
            }
        }
    }

    private class DefaultP2PConnectionListener implements P2PConnectionListener {

        @Override
        public void onConnectivityEvent(final P2PConnectionEvent event) {

            LOG.debug("Got connectivity event: {}", event);
            Events.asyncEventBus().post(event);
            XMPPConnection connection = client.get().getXmppConnection();
            if (connection == previousConnection) {
                //only add packet listener once
                return;
            }
            previousConnection = connection;

            connection.addPacketListener(new PingListener(),
                    new IQTypeFilter(org.jivesoftware.smack.packet.IQ.Type.RESULT));
        }
    }

    /**
     * Connect to Google Talk's XMPP servers using the supplied XmppCredentials
     */
    public void connect(final XmppCredentials credentials)
        throws IOException, CredentialException, NotInClosedBetaException {
        LOG.debug("Connecting to XMPP servers with credentials...");
        this.closedBetaEvent = null;
        final InetSocketAddress plainTextProxyRelayAddress =
            LanternUtils.isa("127.0.0.1",
                LanternUtils.PLAINTEXT_LOCALHOST_PROXY_PORT);

        if (this.client.get() == null) {
            makeClient(plainTextProxyRelayAddress);
        } else {
            LOG.debug("Using existing client for xmpp handler: "+hashCode());
        }

        // This is a global, backup listener added to the client. We might
        // get notifications of messages twice in some cases, but that's
        // better than the alternative of sometimes not being notified
        // at all.
        LOG.debug("Adding message listener...");
        this.client.get().addMessageListener(typedListener);

        Events.eventBus().post(
            new GoogleTalkStateEvent("", GoogleTalkState.connecting));

        login(credentials);

        // Note we don't consider ourselves connected in get mode until we
        // actually get proxies to work with.
        final XMPPConnection connection = this.client.get().getXmppConnection();
        getStunServers(connection);

        // Make sure all connections between us and the server are stored
        // OTR.
        modelUtils.syncConnectingStatus("Activating Google Talk pseudo-OTR...");
        LanternUtils.activateOtr(connection);

        LOG.debug("Connection ID: {}", connection.getConnectionID());

        modelUtils.syncConnectingStatus("Waiting for message from Lantern...");

        DefaultPacketListener listener = new DefaultPacketListener();
        connection.addPacketListener(listener, listener);

        gTalkSharedStatus();
        updatePresence();

        waitForClosedBetaStatus(credentials.getUsername());
        modelUtils.syncConnectingStatus("Lantern message received...");
    }

    private void makeClient(final InetSocketAddress plainTextProxyRelayAddress)
            throws IOException {
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

        client.set(makeXmppP2PHttpClient(plainTextProxyRelayAddress,
                sessionListener));
        LOG.debug("Set client for xmpp handler: "+hashCode());

        client.get().addConnectionListener(new DefaultP2PConnectionListener());
    }

    private void getStunServers(final XMPPConnection connection) {
        modelUtils.syncConnectingStatus("Gathering servers...");
        final Collection<InetSocketAddress> googleStunServers =
                XmppUtils.googleStunServers(connection);
        StunServerRepository.setStunServers(googleStunServers);
        this.model.getSettings().setStunServers(
                new HashSet<String>(toStringServers(googleStunServers)));
    }

    private void login(final XmppCredentials credentials) throws IOException,
            CredentialException {
        try {
            this.client.get().login(credentials);

            modelUtils.syncConnectingStatus("Logged in to Google Talk...");
            // Preemptively create our key.
            this.keyStoreManager.getBase64Cert(getJid());

            LOG.debug("Sending connected event");
            Events.eventBus().post(
                new GoogleTalkStateEvent(getJid(), GoogleTalkState.connected));
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
    }

    private XmppP2PClient<FiveTuple> makeXmppP2PHttpClient(
            final InetSocketAddress plainTextProxyRelayAddress,
            final SessionSocketListener sessionListener) throws IOException {
        return P2PEndpoints.newXmppP2PHttpClient(
                "shoot", natPmpService,
                this.upnpService, this.mappedServer,
                this.socketsUtil.newTlsSocketFactory(),
                this.socketsUtil.newTlsServerSocketFactory(),
                plainTextProxyRelayAddress, sessionListener, false,
                new UdtRelayServerFiveTupleListener());
    }

    private void handleConnectionFailure() {
        Events.eventBus().post(
            new GoogleTalkStateEvent("", GoogleTalkState.LOGIN_FAILED));
    }

    private void waitForClosedBetaStatus(final String email)
        throws NotInClosedBetaException {
        if (this.modelUtils.isInClosedBeta(email)) {
            LOG.debug("Already in closed beta...");
            return;
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
                LOG.debug("Server notified us we're in the closed beta!");
                return;
            }
        } else {
            LOG.warn("No closed beta event -- timed out!!");
            notInClosedBeta("No closed beta event!!");
        }
    }

    /** The default packet listener automatically
     *
     *
     */
    private class DefaultPacketListener implements PacketListener, PacketFilter {
        @Override
        public void processPacket(final Packet pack) {
            final Runnable runner = new Runnable() {

                @Override
                public void run() {
                    final Presence pres = (Presence) pack;
                    LOG.debug("Processing packet!! {}", pres.toXML());
                    final String from = pres.getFrom();
                    LOG.debug("Responding to presence from '{}' and to '{}'",
                        from, pack.getTo());

                    final Type type = pres.getType();
                    // Allow subscription requests from the lantern bot.
                    if (LanternUtils.isLanternHub(from)) {
                        handleHubMessage(pack, pres, from, type);
                    } else {
                        handlePeerMessage(pack, pres, from, type);
                    }
                }
            };
            xmppProcessors.execute(runner);
        }

        private void handlePeerMessage(final Packet pack,
                final Presence pres, final String from, final Type type) {
            switch (type) {
            case available:
                return;
            case error:
                LOG.warn("Got error packet!! {}", pack.toXML());
                return;
            case subscribe:
                LOG.debug("Adding subscription request from: {}", from);

                // Did we originally invite them and they're
                // subscribing back? Auto-allow if so.
                if (roster.autoAcceptSubscription(from)) {
                    subscribed(from);
                } else {
                    LOG.debug("We didn't invite " + from);
                }

                // XMPP requires says that we MUST reply to this request with
                // either 'subscribed' or 'unsubscribed'. But we don't even know
                // if this is a Lantern request yet, so we can't reply yet.  But
                // fortunately, we don't have a timeline to respond.  We need to
                // mark that we owe this user a reply, so that if we do decide to
                // friend the user, we can approve the request.

                roster.addIncomingSubscriptionRequest(pres);

                break;
            case subscribed:
                break;
            case unavailable:
                // TODO: We should remove the peer from our proxy
                // lists!!
                return;
            case unsubscribe:
                // The user is unsubscribing from us, so we will no longer be
                // able to send them messages.  However, we still trust them
                // so there is no reason to remove them from the friends list.
                // If they later resubscribe to us, we don't need to go
                // through the whole friending process again.
                return;
            case unsubscribed:
                break;
            }
        }

        /** Allow the hub to subscribe to messages from us. */
        private void handleHubMessage(final Packet pack,
                final Presence pres, final String from, final Type type) {
            if (type == Type.subscribe) {
                final Presence packet =
                    new Presence(Presence.Type.subscribed);
                packet.setTo(from);
                packet.setFrom(pack.getTo());
                XMPPConnection connection = client.get().getXmppConnection();
                connection.sendPacket(packet);
            } else {
                LOG.debug("Non-subscribe packet from hub? {}",
                    pres.toXML());
            }
        }

        @Override
        public boolean accept(final Packet packet) {
            if (packet instanceof Presence) {
                return true;
            } else {
                LOG.debug("Not a presence packet: {}", packet.toXML());
            }
            return false;
        }

    };

    private void notInClosedBeta(final String msg)
        throws NotInClosedBetaException {
        LOG.debug("Not in closed beta!");
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
        LOG.debug("Disconnecting!!");
        lastJson = "";
        /*
        LanternHub.eventBus().post(
            new GoogleTalkStateEvent(GoogleTalkState.LOGGING_OUT));
        */

        final XmppP2PClient<FiveTuple> cl = this.client.get();
        if (cl != null) {
            this.client.get().logout();
            //this.client.set(null);
        }

        Events.eventBus().post(
            new GoogleTalkStateEvent("", GoogleTalkState.notConnected));

        proxyTracker.clearPeerProxySet();
        this.closedBetaEvent = null;

        // This is mostly logged for debugging thorny shutdown issues...
        LOG.debug("Finished disconnecting XMPP...");
    }

    private void processLanternHubMessage(final Message msg) {
        Connectivity connectivity = model.getConnectivity();
        if (!connectivity.getLanternController()) {
            connectivity.setLanternController(true);
            Events.sync(SyncPath.CONNECTIVITY_LANTERN_CONTROLLER, true);
        }
        LOG.debug("Lantern controlling agent response");
        this.hubAddress = msg.getFrom();
        final String to = XmppUtils.jidToUser(msg.getTo());
        LOG.debug("Set hub address to: {}", hubAddress);
        final String body = msg.getBody();
        LOG.debug("Hub message body: {}", body);
        final Object obj = JSONValue.parse(body);
        final JSONObject json = (JSONObject) obj;

        final Boolean inClosedBeta =
            (Boolean) json.get(LanternConstants.INVITED);

        if (inClosedBeta != null) {
            Events.asyncEventBus().post(new ClosedBetaEvent(to, inClosedBeta));
        } else {
            Events.asyncEventBus().post(new ClosedBetaEvent(to, false));
        }

        handleSetDelay(json);
        handleUpdate(json);
        handleProcessedInvites(json);
        handleFailedInvites(json);
        handleFriends(json);
    }

    private void handleFriends(JSONObject json) {
        @SuppressWarnings("unchecked")
        final List<Object> friendUpdates = (List<Object>) json.get(LanternConstants.FRIENDS);
        Friends friends = model.getFriends();
        if (friendUpdates != null) {
            for (Object friendObj: friendUpdates) {
                JSONObject friendJson = (JSONObject) friendObj;

                String email = (String) friendJson.get("email");
                Status status = Status.valueOf((String) friendJson.get("status"));
                String name = (String) friendJson.get("name");
                Long nextQuery = (Long) friendJson.get("nextQuery");
                Long lastUpdated = (Long) friendJson.get("lastUpdated");

                Friend friend = new Friend(email, status, name, nextQuery, lastUpdated);

                //we need to check if we have had a more-recent update of this friend.
                //that could happen if we had made some local changes while waiting
                //to hear back from the XMPP server.  It's not very likely.
                Friend old = friends.get(email);
                if (old != null && old.getLastUpdated() > lastUpdated) {
                    friends.setNeedsSync(true);
                } else {
                    friends.add(friend);
                }
            }
            Events.sync(SyncPath.FRIENDS, friends.getFriends());
        }
    }

    private void handleFailedInvites(final JSONObject json) {
        //list of invites that the server has given up on processing
        //perhaps because you are out of invites.
        @SuppressWarnings("unchecked")
        final List<Object> failedInvites = (List<Object>) json.get(LanternConstants.FAILED_INVITES_KEY);
        LOG.info("Failed invites: " + failedInvites);
        if (failedInvites == null) {
            return;
        }
        for (Object inviteObj : failedInvites) {
            JSONObject invite = (JSONObject) inviteObj;
            String invitee = (String) invite.get(LanternConstants.INVITED_EMAIL);
            if (!model.getPendingInvites().contains(invitee)) {
                // we already notified about this one
                continue;
            }
            String reason = (String) invite
                    .get(LanternConstants.INVITE_FAILED_REASON);
            LOG.info("Failed invite to " + invitee + " because " + reason);
            model.removePendingInvite(invitee);
            String message = "Invite to " + invitee + " failed: " + reason;
            model.addNotification(message, MessageType.error);
            Events.sync(SyncPath.NOTIFICATIONS, model.getNotifications());
        }
    }

    private void handleProcessedInvites(final JSONObject json) {
        //list of invites that the server has processed
        @SuppressWarnings("unchecked")
        final List<Object> invited = (List<Object>) json.get(LanternConstants.INVITED_KEY);
        if (invited == null) {
            return;
        }
        for (Object invite : invited) {
            model.removePendingInvite((String) invite);
        }
    }

    @SuppressWarnings("unchecked")
    private void handleUpdate(final JSONObject json) {
        // This is really a JSONObject, but that itself is a map.
        final JSONObject update =
            (JSONObject) json.get(LanternConstants.UPDATE_KEY);
        if (update == null) {
            return;
        }
        LOG.info("About to propagate update...");
        final Map<String, Object> event = new HashMap<String, Object>();
        event.putAll(update);
        Events.asyncEventBus().post(new UpdateEvent(event));
    }

    private void handleSetDelay(final JSONObject json) {
        final Long delay =
            (Long) json.get(LanternConstants.UPDATE_TIME);
        LOG.debug("Server sent delay of: "+delay);
        if (delay == null) {
            return;
        }
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
            LOG.debug("Scheduled next info request in {} milliseconds", delay);
        } else {
            LOG.debug("Ignoring duplicate info request scheduling- "
                    + "scheduled request {} milliseconds ago.", elapsed);
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

    /**
     * Updates the user's presence. We also include any stats and friends
     * updates in this message. Note that periodic presence updates are also
     * used on the server side to verify which clients are actually available.
     *
     * We in part send presence updates instead of typical chat messages to get
     * around these messages showing up in the user's gchat window.
     */
    private void updatePresence() {
        if (!isLoggedIn()) {
            LOG.info("Not updating presence when we're not connected");
            return;
        }

        final XMPPConnection conn = this.client.get().getXmppConnection();

        if (conn == null || !conn.isConnected()) {
            return;
        }

        LOG.info("Sending presence available");

        // OK, this is bizarre. For whatever reason, we **have** to send the
        // following packet in order to get presence events from our peers.
        // DO NOT REMOVE THIS MESSAGE!! See XMPP spec.
        final Presence pres = new Presence(Presence.Type.available);
        conn.sendPacket(pres);

        final Presence forHub = new Presence(Presence.Type.available);
        forHub.setTo(LanternClientConstants.LANTERN_JID);

        forHub.setProperty("mode", model.getSettings().getMode().toString());
        final String str = JsonUtils.jsonify(stats);
        LOG.debug("Reporting data: {}", str);
        if (!this.lastJson.equals(str)) {
            this.lastJson = str;
            forHub.setProperty("stats", str);
            stats.resetCumulativeStats();
        } else {
            LOG.info("No new stats to report");
        }

        Friends friends = model.getFriends();
        if (friends.needsSync()) {
            String friendsJson = JsonUtils.jsonify(friends);
            forHub.setProperty(LanternConstants.FRIENDS, friendsJson);
            friends.setNeedsSync(false);
        }

        conn.sendPacket(forHub);
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
            // Only exchange certs with peers based on kscope ads.

            // OK, we just request a certificate every time we get a present
            // peer. If we get a response, this peer will be added to active
            // peer URIs.
            //sendAndRequestCert(uri);
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
                //only process kscope ads delivered by friends
                if (model.isFriend(from)) {
                    LOG.debug("Handling KSCOPE ADVERTISEMENT");
                    final String payload =
                            (String) msg.getProperty(
                                    LanternConstants.KSCOPE_ADVERTISEMENT_KEY);
                    if (StringUtils.isNotBlank(payload)) {
                        processKscopePayload(from, payload);
                    } else {
                        LOG.error("kscope ad with no payload? "+msg.toXML());
                    }
                }
                break;
            default:
                LOG.warn("Did not understand type: "+type);
                break;
        }
    }

    private void processKscopePayload(final String from, final String payload) {
        LOG.debug("Processing payload: {}", payload);
        final ObjectMapper mapper = new ObjectMapper();
        try {
            final LanternKscopeAdvertisement ad =
                mapper.readValue(payload, LanternKscopeAdvertisement.class);

            final URI uri = new URI(ad.getJid());
            if (this.kscopeAdHandler.handleAd(uri, ad)) {
                sendAndRequestCert(uri);
            } else {
                LOG.debug("Not requesting cert -- duplicate kscope ad?");
            }
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
        //msg.setProperty(P2PConstants.MAC, this.model.getNodeId());
        msg.setProperty(P2PConstants.CERT,
            this.keyStoreManager.getBase64Cert(getJid()));
        this.client.get().getXmppConnection().sendPacket(msg);
    }

    private void processInfoData(final Message msg) {
        LOG.debug("Processing INFO data from request or response.");
        // This just makes sure it's a valid URI!!
        final URI uri;
        try {
            uri = new URI(msg.getFrom());
        } catch (final URISyntaxException e) {
            LOG.error("Could not create URI from: {}", msg.getFrom());
            return;
        }

        //final String mac = (String) msg.getProperty(P2PConstants.MAC);
        final String base64Cert = (String) msg.getProperty(P2PConstants.CERT);

        LOG.debug("Base 64 cert: {}", base64Cert);

        if (StringUtils.isNotBlank(base64Cert)) {
            LOG.debug("Got certificate:\n"+
                new String(Base64.decodeBase64(base64Cert),
                    LanternConstants.UTF8));
            // Add the peer if we're able to add the cert.
            this.kscopeAdHandler.onBase64Cert(uri, base64Cert);
        } else {
            LOG.error("No cert for peer?");
        }
    }

    @Override
    public String getJid() {
        // We may have already disconnected on shutdown, for example, so check
        // for null.
        if (this.client.get() != null &&
            this.client.get().getXmppConnection() != null &&
            this.client.get().getXmppConnection().getUser() != null) {
            return this.client.get().getXmppConnection().getUser().trim();
        }
        return "";
    }

    private void sendAndRequestCert(final URI peer) {
        LOG.debug("Requesting cert from {}", peer);
        final Message msg = new Message();
        msg.setProperty(P2PConstants.MESSAGE_TYPE,
            XmppMessageConstants.INFO_REQUEST_TYPE);

        msg.setTo(peer.toASCIIString());
        // Set our certificate in the request as well -- we want to make
        // extra sure these get through!
        //msg.setProperty(P2PConstants.MAC, this.model.getNodeId());
        msg.setProperty(P2PConstants.CERT,
            this.keyStoreManager.getBase64Cert(getJid()));
        if (isLoggedIn()) {
            this.client.get().getXmppConnection().sendPacket(msg);
        } else {
            LOG.debug("No longer logged in? Not sending cert");
        }
    }

    @Override
    public XmppP2PClient<FiveTuple> getP2PClient() {
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
    public boolean sendInvite(final Friend friend, boolean redo) {
        LOG.info("Sending invite");

        String email = friend.getEmail();

        if (StringUtils.isBlank(this.hubAddress)) {
            LOG.info("Blank hub address when sending invite?");
            return true;
        }

        final Set<String> invited = roster.getInvited();
        if ((!redo) && invited.contains(email)) {
            LOG.info("Already invited");
            return false;
        }
        final XMPPConnection conn = this.client.get().getXmppConnection();

        final Roster rost = conn.getRoster();

        final Presence pres = new Presence(Presence.Type.available);
        pres.setTo(LanternClientConstants.LANTERN_JID);

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

        pres.setProperty(LanternConstants.INVITER_REFRESH_TOKEN,
                         this.model.getSettings().getRefreshToken());

        final RosterEntry entry = rost.getEntry(email);
        if (entry != null) {
            final String name = entry.getName();
            if (StringUtils.isNotBlank(name)) {
                pres.setProperty(LanternConstants.INVITEE_NAME, name);
            }
        }

        pres.setProperty(LanternConstants.FRIEND, JsonUtils.jsonify(friend));

        invited.add(email);

        final Runnable runner = new Runnable() {

            @Override
            public void run() {
                conn.sendPacket(pres);
            }
        };
        final Thread t = new Thread(runner, "Invite-Thread");
        t.setDaemon(true);
        t.start();

        addToRoster(email);
        return true;
    }

    /** Try to reconnect to the xmpp server */
    private void reconnect() {
        //this will trigger XmppP2PClient's internal reconnection logic
        if (hasConnection()) {
            client.get().getXmppConnection().disconnect();
        }
        // Otherwise the client should already be trying to connect.
    }

    private boolean hasConnection() {
        return client.get() != null && client.get().getXmppConnection() != null;
    }

    @Override
    public void subscribe(final String jid) {
        LOG.debug("Sending subscribe message to: {}", jid);
        final Presence packet = new Presence(Presence.Type.subscribe);
        packet.setTo(jid);
        //final String json = JsonUtils.jsonify(this.model.getProfile());
        //packet.setProperty(XmppMessageConstants.PROFILE, json);
        final XMPPConnection conn = this.client.get().getXmppConnection();
        conn.sendPacket(packet);
    }

    @Override
    public void subscribed(final String jid) {
        LOG.debug("Sending subscribed message to: {}", jid);
        sendTypedPacket(jid, Presence.Type.subscribed);
    }

    @Override
    public void unsubscribe(final String jid) {
        LOG.debug("Sending unsubscribe message to: {}", jid);
        sendTypedPacket(jid, Presence.Type.unsubscribe);
    }

    @Override
    public void unsubscribed(final String jid) {
        LOG.debug("Sending unsubscribed message to: {}", jid);
        sendTypedPacket(jid, Presence.Type.unsubscribed);
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
            LOG.debug("Inviting user to join roster: {}", email);
            try {
                // Note this also sends a subscription request!!
                rost.createEntry(email,
                    StringUtils.substringBefore(email, "@"), new String[]{});
            } catch (final XMPPException e) {
                LOG.error("Could not create entry?", e);
            }
        } else {
            LOG.debug("User already on roster...");
        }
    }

    @Override
    public void removeFromRoster(final String email) {
        final XMPPConnection conn = this.client.get().getXmppConnection();
        final Roster rost = conn.getRoster();
        final RosterEntry entry = rost.getEntry(email);
        if (entry != null) {
            LOG.debug("Removing user from roster: {}", email);
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
            LOG.debug("Registering MBean with name: {}", oName);
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

    @Override
    public void sendPacket(final Packet packet) {
        this.client.get().getXmppConnection().sendPacket(packet);
    }
}
