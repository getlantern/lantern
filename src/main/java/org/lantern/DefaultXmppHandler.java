package org.lantern;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Collection;
import java.util.HashSet;
import java.util.Set;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.atomic.AtomicReference;

import javax.security.auth.login.CredentialException;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang3.SystemUtils;
import org.codehaus.jackson.JsonParseException;
import org.codehaus.jackson.map.JsonMappingException;
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
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.lantern.event.Events;
import org.lantern.event.GoogleTalkStateEvent;
import org.lantern.event.ResetEvent;
import org.lantern.event.UpdateEvent;
import org.lantern.event.UpdatePresenceEvent;
import org.lantern.kscope.KscopeAdHandler;
import org.lantern.kscope.LanternKscopeAdvertisement;
import org.lantern.kscope.ReceivedKScopeAd;
import org.lantern.network.NetworkTracker;
import org.lantern.proxy.ProxyTracker;
import org.lantern.proxy.UdtServerFiveTupleListener;
import org.lantern.state.ClientFriend;
import org.lantern.state.Connectivity;
import org.lantern.state.FriendsHandler;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;
import org.lantern.state.SyncPath;
import org.lantern.state.Version.Installed;
import org.lantern.util.Threads;
import org.lastbamboo.common.ice.MappedServerSocket;
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
        SmackConfiguration.setPacketReplyTimeout(60 * 1000);
        SmackConfiguration.setKeepAliveInterval(5 * 1000);
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

    private GoogleTalkState state;

    private final NatPmpService natPmpService;

    private final UpnpService upnpService;

    private MappedServerSocket mappedServer;

    private final Timer timer;

    private final LanternKeyStoreManager keyStoreManager;

    private final LanternSocketsUtil socketsUtil;

    private final LanternXmppUtil xmppUtil;

    private final Model model;

    private final ModelUtils modelUtils;

    private final RosterHandler roster;

    private final ProxyTracker proxyTracker;

    private final KscopeAdHandler kscopeAdHandler;

    private final ExecutorService xmppProcessors =
        Threads.newCachedThreadPool("Smack-XMPP-Message-Processing-");

    private final UdtServerFiveTupleListener udtFiveTupleListener;

    private final FriendsHandler friendsHandler;
    
    private final NetworkTracker<String, URI, ReceivedKScopeAd> networkTracker;

    private final Censored censored;

    /**
     * Creates a new XMPP handler.
     */
    @Inject
    public DefaultXmppHandler(final Model model,
        final Timer updateTimer,
        final LanternKeyStoreManager keyStoreManager,
        final LanternSocketsUtil socketsUtil,
        final LanternXmppUtil xmppUtil,
        final ModelUtils modelUtils,
        final RosterHandler roster, 
        final ProxyTracker proxyTracker,
        final KscopeAdHandler kscopeAdHandler,
        final NatPmpService natPmpService,
        final UpnpService upnpService,
        final UdtServerFiveTupleListener udtFiveTupleListener,
        final FriendsHandler friendsHandler,
        final NetworkTracker<String, URI, ReceivedKScopeAd> networkTracker,
        final Censored censored) {
        this.model = model;
        this.timer = updateTimer;
        this.keyStoreManager = keyStoreManager;
        this.socketsUtil = socketsUtil;
        this.xmppUtil = xmppUtil;
        this.modelUtils = modelUtils;
        this.roster = roster;
        this.proxyTracker = proxyTracker;
        this.kscopeAdHandler = kscopeAdHandler;
        this.natPmpService = natPmpService;
        this.upnpService = upnpService;
        this.udtFiveTupleListener = udtFiveTupleListener;
        this.friendsHandler = friendsHandler;
        this.networkTracker = networkTracker;
        this.censored = censored;
        Events.register(this);
        
        this.modelUtils.loadClientSecrets();

        this.mappedServer = new LanternMappedTcpAnswererServer(natPmpService,
            upnpService, new InetSocketAddress(this.model.getSettings().getServerPort()));
        //setupJmx();
    }

    @Override
    public MappedServerSocket getMappedServer() {
        return mappedServer;
    }

    @Override
    public void stop() {
        LOG.debug("Stopping XMPP handler...");
        disconnect();
        LOG.debug("Stopped XMPP handler...");
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

    @Override
    public synchronized void connect() throws IOException, CredentialException {
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
        
        // Wait until the last minute to configure XMPP, particularly because
        // the isCensored call will wait for the local server to run and will
        // look up the public IP.
        boolean alwaysUseProxy = this.censored.isCensored() || LanternUtils.isGet();
        XmppUtils.setGlobalConfig(this.xmppUtil.xmppConfig(alwaysUseProxy));
        XmppUtils.setGlobalProxyConfig(this.xmppUtil.xmppConfig(true));
        
        LOG.debug("Connecting to XMPP servers...");
        connectViaOAuth2();
    }

    private void connectViaOAuth2() throws IOException,
            CredentialException {
        final XmppCredentials credentials =
            this.modelUtils.newGoogleOauthCreds(LanternConstants.UNCENSORED_ID);

        LOG.debug("Logging in with credentials: {}", credentials);
        connect(credentials);
    }

    @Override
    public void connect(final String email, final String pass)
        throws IOException, CredentialException {
        //connect(new PasswordCredentials(email, pass, getResource()));
    }

    /**
     * Connect to Google Talk's XMPP servers using the supplied XmppCredentials
     */
    private void connect(final XmppCredentials credentials)
        throws IOException, CredentialException {
        LOG.debug("Connecting to XMPP servers with credentials...");
        // This address doesn't appear to be used anywhere, setting to null
        final InetSocketAddress plainTextProxyRelayAddress = null;

        if (this.client.get() == null) {
            makeClient(plainTextProxyRelayAddress);
        } else {
            LOG.debug("Using existing client for xmpp handler: "+hashCode());
        }

        Events.eventBus().post(
            new GoogleTalkStateEvent("", GoogleTalkState.connecting));

        login(credentials);

        // Note we don't consider ourselves connected in get mode until we
        // actually get proxies to work with.
        final XMPPConnection connection = this.client.get().getXmppConnection();
        getStunServers(connection);

        // Make sure all connections between us and the server are stored
        // OTR.
        modelUtils.syncConnectingStatus(Tr.tr(MessageKey.CONFIGURING_CONNECTION));
        LanternUtils.activateOtr(connection);

        LOG.debug("Connection ID: {}", connection.getConnectionID());

        modelUtils.syncConnectingStatus(Tr.tr(MessageKey.CHECKING_INVITE));

        DefaultPacketListener listener = new DefaultPacketListener();
        connection.addPacketListener(listener, listener);

        gTalkSharedStatus();
        updatePresence();

        modelUtils.syncConnectingStatus(Tr.tr(MessageKey.INVITED));
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

        this.client.set(makeXmppP2PHttpClient(plainTextProxyRelayAddress,
                sessionListener));
        
        // This is a global, backup listener added to the client. We might
        // get notifications of messages twice in some cases, but that's
        // better than the alternative of sometimes not being notified
        // at all.
        LOG.debug("Adding message listener...");
        this.client.get().addMessageListener(typedListener);
        
        LOG.debug("Set client for xmpp handler: "+hashCode());
    }

    private void getStunServers(final XMPPConnection connection) {
        modelUtils.syncConnectingStatus(Tr.tr(MessageKey.STUN_SERVER_LOOKUP));
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

            modelUtils.syncConnectingStatus(Tr.tr(MessageKey.LOGGED_IN));
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
                this.socketsUtil.newTlsSocketFactoryJavaCipherSuites(),
                this.socketsUtil.newTlsServerSocketFactory(),
                plainTextProxyRelayAddress, sessionListener, false,
                udtFiveTupleListener);
    }

    private void handleConnectionFailure() {
        Events.eventBus().post(
            new GoogleTalkStateEvent("", GoogleTalkState.LOGIN_FAILED));
    }

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
                peerAvailable(from, pres);
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


                LOG.debug("Adding subscription request");
                friendsHandler.addIncomingSubscriptionRequest(pres.getFrom());
                break;
            case subscribed:
                break;
            case unavailable:
                peerUnavailable(from, pres);
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

    private Set<String> toStringServers(
        final Collection<InetSocketAddress> googleStunServers) {
        final Set<String> strings = new HashSet<String>();
        for (final InetSocketAddress isa : googleStunServers) {
            // If we get an unresolved name, isa.getAddress() will return
            // null. We don't just call getHostName because that will trigger
            // a reverse DNS lookup if it is resolved. Finally, getHostString
            // is only available in Java 7.
            if (!isa.isUnresolved()) {
                strings.add(isa.getAddress().getHostAddress()+":"+isa.getPort());
            } else {
                strings.add(isa.getHostName()+":"+isa.getPort());
            }
        }
        return strings;
    }

    @Override
    public void disconnect() {
        LOG.debug("Disconnecting!!");
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

        this.proxyTracker.clearPeerProxySet();

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
        LOG.debug("Set hub address to: {}", LanternClientConstants.LANTERN_JID);
        final String body = msg.getBody();
        LOG.debug("Hub message body: {}", body);
        final Object obj = JSONValue.parse(body);
        final JSONObject json = (JSONObject) obj;
        
        handleSetDelay(json);
        handleVersionUpdate(json);

        model.setUserGuid((String) json.get(LanternConstants.USER_GUID));
        sendOnDemandValuesToControllerIfNecessary(json);
    }

    @SuppressWarnings("unchecked")
    private boolean handleVersionUpdate(JSONObject json) {
        // This is really a JSONObject, but that itself is a map.
        JSONObject versionInfo = (JSONObject)
            json.get(LanternConstants.UPDATE_KEY);
        if (versionInfo == null) {
            LOG.debug("no version info");
            return false;
        }
        LOG.debug(String.format("Posting UpdateEvent: %1$s", versionInfo.toJSONString()));
        Events.asyncEventBus().post(new UpdateEvent(versionInfo));
        return true;
    }

    private boolean handleSetDelay(final JSONObject json) {
        final Long delay =
            (Long) json.get(LanternConstants.UPDATE_TIME);
        LOG.debug("Server sent delay of: "+delay);
        if (delay == null) {
            return false;
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
        return true;
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
            LOG.debug("Not updating presence when we're not connected");
            return;
        }

        final XMPPConnection conn = this.client.get().getXmppConnection();

        if (conn == null || !conn.isConnected()) {
            return;
        }

        LOG.debug("Sending presence available");

        // OK, this is bizarre. For whatever reason, we **have** to send the
        // following packet in order to get presence events from our peers.
        // DO NOT REMOVE THIS MESSAGE!! See XMPP spec.
        final Presence pres = new Presence(Presence.Type.available);
        conn.sendPacket(pres);

        final Presence forHub = new Presence(Presence.Type.available);
        forHub.setTo(LanternClientConstants.LANTERN_JID);

        forHub.setProperty("language", SystemUtils.USER_LANGUAGE);
 
        Installed installed = model.getVersion().getInstalled();
        forHub.setProperty(LanternConstants.UPDATE_KEY, installed.toString());
        forHub.setProperty(LanternConstants.OS_KEY, model.getSystem().getOs());
        forHub.setProperty(LanternConstants.ARCH_KEY, model.getSystem().getArch());

        forHub.setProperty("instanceId", model.getInstanceId());
        forHub.setProperty("countryCode", model.getLocation().getCountry());
        forHub.setProperty("mode", model.getSettings().getMode().toString());
        // Counterintuitive as it might seem at first glance, this is correct.
        //
        // If I'm a fallback proxy I need to send the host and port at which
        // *I'm* listening.
        //
        // If I'm a non-fallback proxy client I need to send the host and port
        // that *my fallback proxy* is listening to.
        //
        // XXX: Legacy; we should be able to get rid of this soon.
        if (LanternUtils.isFallbackProxy()) {
            sendHostAndPort(forHub);
        } else {
            //sendFallbackHostAndPort(forHub);
        }
        forHub.setProperty(LanternConstants.IS_FALLBACK_PROXY,
                           LanternUtils.isFallbackProxy());
        
        /*
        final FriendsHandler friends = model.getFriends();
        if (friends.needsSync()) {
            String friendsJson = JsonUtils.jsonify(friends);
            forHub.setProperty(LanternConstants.FRIENDS, friendsJson);
            friends.setNeedsSync(false);
        }
        */

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
        if (p.isAvailable()) {
            LOG.info("Processing available peer");
            // Only exchange certs with peers based on kscope ads.

            // OK, we just request a certificate every time we get a present
            // peer. If we get a response, this peer will be added to active
            // peer URIs.
            //sendAndRequestCert(uri);
        }
        else {
            LOG.info("Removing JID for peer '" + from);
            try {
                this.networkTracker.instanceOffline(from, new URI(from));
            } catch (URISyntaxException e) {
                LOG.error("Unable to parse JabberID: {}", from, e);
            }
        }
    }

    private void processTypedMessage(final Message msg, final Integer type) {
        final String from = msg.getFrom();
        LOG.info("Processing typed message from {}", from);

        switch (type) {
            case (XmppMessageConstants.INFO_REQUEST_TYPE):
                LOG.debug("Handling INFO request from {}", from);
                if (!this.friendsHandler.isRejected(from)) {
                    processInfoData(msg);
                } else {
                    LOG.debug("Not processing message from rejected friend {}", 
                            from);
                }
                sendInfoResponse(from);
                break;
            case (XmppMessageConstants.INFO_RESPONSE_TYPE):
                LOG.debug("Handling INFO response from {}", from);
                if (!this.friendsHandler.isRejected(from)) {
                    processInfoData(msg);
                }
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
        LOG.debug("Processing payload: {}", payload);
        try {
            final LanternKscopeAdvertisement ad =
                JsonUtils.OBJECT_MAPPER.readValue(payload, LanternKscopeAdvertisement.class);

            final String jid = ad.getJid();
            // This could easily be a duplicate kscope ad here, however the
            // remote peer may have restarted and therefore generated a new 
            // certificate, so we request it every time in case.
            this.kscopeAdHandler.handleAd(jid, ad);
            sendAndRequestCert(jid);
        } catch (final JsonParseException e) {
            LOG.warn("Could not parse JSON", e);
        } catch (final JsonMappingException e) {
            LOG.warn("Could not map JSON", e);
        } catch (final IOException e) {
            LOG.warn("IO error parsing JSON", e);
        }
    }

    private void sendInfoResponse(final String from) {
        LOG.info("Sending certificate to {}", from);
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
            LOG.trace("Got certificate for {}:\n{}", uri, 
                new String(Base64.decodeBase64(base64Cert),
                    LanternConstants.UTF8).replaceAll("\u0007", "[bell]")); // don't ring any bells
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

    private void sendAndRequestCert(final String peer) {
        LOG.debug("Requesting cert from {}", peer);
        final Message msg = new Message();
        msg.setProperty(P2PConstants.MESSAGE_TYPE,
            XmppMessageConstants.INFO_REQUEST_TYPE);

        msg.setTo(peer);
        // Set our certificate in the request as well -- we want to make
        // extra sure these get through!
        //msg.setProperty(P2PConstants.MAC, this.model.getNodeId());
        String cert = this.keyStoreManager.getBase64Cert(getJid());
        msg.setProperty(P2PConstants.CERT, cert);
        if (isLoggedIn()) {
            LOG.debug("Sending cert {}", cert);
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
    public void subscribe(final String jid) {
        LOG.debug("Sending subscribe message to: {}", jid);
        sendTypedPacket(jid, Presence.Type.subscribe);
    }

    @Override
    public void subscribed(final String jid) {
        LOG.debug("Sending subscribed message to: {}", jid);
        sendTypedPacket(jid, Presence.Type.subscribed);
    }

    private void sendTypedPacket(final String jid, final Type type) {
        final Presence packet = new Presence(type);
        packet.setTo(jid);
        sendPacket(packet);
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
                return;
            } catch (final XMPPException e) {
                LOG.error("Could not create entry?", e);
            }
        } else {
            LOG.debug("User already on roster...");
        }
    }

    @Subscribe
    public void onReset(final ResetEvent event) {
        disconnect();
    }

    @Subscribe
    public void sendPacket(final Packet packet) {
        XmppP2PClient<FiveTuple> xmppP2PClient = this.client.get();
        if (xmppP2PClient == null) {
            throw new IllegalStateException("Can't send packets without a client");
        }
        final XMPPConnection conn = xmppP2PClient.getXmppConnection();
        if (conn == null) {
            throw new IllegalStateException("Can't send packets while offline");
        }
        conn.sendPacket(packet);
    }

    private void peerUnavailable(final String from, final Presence pres) {
        if (!LanternXmppUtils.isLanternJid(from)) {
            return;
        }
        final String email = XmppUtils.jidToUser(from);
        final ClientFriend friend = this.friendsHandler.getFriend(email);
        if (friend == null) {
            // Some error occurred!
            return;
        }
        
        // We don't track logged in or mode separately on our server since
        // XMPP takes care of it - that's why we don't update the server here.
        friend.setLoggedIn(false);
        friend.setMode(pres.getMode());
        this.friendsHandler.syncFriends();
    }
    
    private void peerAvailable(final String from, final Presence pres) {
        if (!LanternXmppUtils.isLanternJid(from)) {
            return;
        }
        LOG.debug("Got peer available...");
        final String email = XmppUtils.jidToUser(from);
        this.friendsHandler.peerRunningLantern(email, pres);

    }

    /**
     * Sends one or more properties to the controller based on a request from
     * the controller.
     * 
     * @param json
     */
    private void sendOnDemandValuesToControllerIfNecessary(JSONObject json) {
        final Presence presence = new Presence(Presence.Type.available);
        if (Boolean.TRUE.equals(json.get(LanternConstants.NEED_REFRESH_TOKEN))) {
            sendToken(presence);
        }
        if (presence.getPropertyNames().size() > 0) {
            LOG.debug("Sending on-demand properties to controller");
            presence.setTo(LanternClientConstants.LANTERN_JID);
            sendPacket(presence);
        } else {
            LOG.debug("Not sending on-demand properties to controller");
        }
    }
    
    private void sendToken(Presence presence) {
        LOG.info("Sending refresh token to controller.");
        presence.setProperty(LanternConstants.REFRESH_TOKEN,
                             this.model.getSettings().getRefreshToken());
    }
    
    private void sendHostAndPort(Presence presence) {
        LOG.info("Sending give mode proxy address to controller.");
        String ip = model.getReportIp();
        if (StringUtils.isBlank(ip)) {
            LOG.error("No host? " + ip);
            return;
        }
        int port = this.model.getSettings().getServerPort();
        String hostAndPort = ip.trim() + ":" + port;
        presence.setProperty(LanternConstants.HOST_AND_PORT, hostAndPort);
    }
    
    /*
    private void sendFallbackHostAndPort(Presence presence) {
        LOG.info("Sending fallback address to controller.");
        InetSocketAddress address = addressForConfiguredFallbackProxy();
        String hostAndPort = addressToHostAndPort(address);
        if (hostAndPort != null) {
            presence.setProperty(LanternConstants.FALLBACK_HOST_AND_PORT,
                    hostAndPort);
        }
    }
    
    private InetSocketAddress addressForConfiguredFallbackProxy() {
        Collection<FallbackProxy> fallbacks
            = this.model.getS3Config().getFallbacks();
        if (fallbacks.isEmpty()) {
            return null;
        } else {
            FallbackProxy fp = fallbacks.iterator().next();
            return new InetSocketAddress(fp.getWanHost(), fp.getWanPort());
        }
    }
    
    private String addressToHostAndPort(InetSocketAddress address) {
        if (address == null) {
            return null;
        } else {
            return String.format("%1$s:%2$s",
                    address.getAddress().getHostAddress(),
                    address.getPort());
        }
    }
    */

    @Override
    public ProxyTracker getProxyTracker() {
        return proxyTracker;
    }
}
