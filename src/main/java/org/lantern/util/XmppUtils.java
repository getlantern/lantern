package org.lantern.util;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import javax.net.SocketFactory;
import javax.security.auth.login.CredentialException;
import javax.xml.xpath.XPathExpressionException;

import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.ConnectionConfiguration.SecurityMode;
import org.jivesoftware.smack.ConnectionListener;
import org.jivesoftware.smack.PacketCollector;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.filter.PacketIDFilter;
import org.jivesoftware.smack.packet.IQ;
import org.jivesoftware.smack.packet.IQ.Type;
import org.jivesoftware.smack.packet.Message;
import org.jivesoftware.smack.packet.Packet;
import org.jivesoftware.smack.packet.RosterPacket;
import org.jivesoftware.smack.packet.XMPPError;
import org.jivesoftware.smack.provider.ProviderManager;
import org.jivesoftware.smack.proxy.ProxyInfo.ProxyType;
import org.jivesoftware.smackx.packet.VCard;
import org.jivesoftware.smackx.provider.VCardProvider;
import org.lastbamboo.common.p2p.P2PConstants;
import org.littleshoot.commom.xmpp.GenericIQProvider;
import org.littleshoot.commom.xmpp.PasswordCredentials;
import org.littleshoot.commom.xmpp.XmppConfig;
import org.littleshoot.commom.xmpp.XmppConnectionRetyStrategy;
import org.littleshoot.commom.xmpp.XmppCredentials;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.dnssec4j.VerifiedAddressFactory;
import org.littleshoot.util.xml.XPathUtils;
import org.littleshoot.util.xml.XmlUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.Document;
import org.w3c.dom.NamedNodeMap;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;
import org.xmlpull.v1.XmlPullParser;

public class XmppUtils {


    private static final Logger LOG = LoggerFactory.getLogger(XmppUtils.class);
    private static ConnectionConfiguration globalConfig;
    private static ConnectionConfiguration globalProxyConfig;

    private XmppUtils() {}

    static {

        ProviderManager.getInstance().addIQProvider("vCard", "vcard-temp",
                new VCardProvider());
        //ProviderManager.getInstance().addIQProvider(
        //    "query", "google:shared-status", new GenericIQProvider());

        ProviderManager.getInstance().addIQProvider(
                "query", "google:shared-status", new GenericIQProvider() {

                    @Override
                    public IQ parseIQ(final XmlPullParser parser) throws Exception {
                        //System.out.println("GOT PULL PARSER: "+parser);
                        return super.parseIQ(parser);
                    }
                });
        ProviderManager.getInstance().addIQProvider(
            "query", "google:nosave", new GenericIQProvider());
        ProviderManager.getInstance().addIQProvider(
            "query", "http://jabber.org/protocol/disco#info",
            new GenericIQProvider());
        ProviderManager.getInstance().addIQProvider(
            "query", "google:jingleinfo", new GenericIQProvider());
        /*
        ProviderManager.getInstance().addIQProvider(
            "query", "jabber:iq:roster", new GenericIQProvider() {

                @Override
                public IQ parseIQ(final XmlPullParser parser) throws Exception {
                    System.out.println("GOT PULL PARSER: "+parser);
                    return super.parseIQ(parser);
                }
            });
        ProviderManager.getInstance().addIQProvider(
            "query", "google:roster", new GenericIQProvider() {

                @Override
                public IQ parseIQ(final XmlPullParser parser) throws Exception {
                    System.out.println("GOT GOOGLE ROSTER PULL PARSER: "+parser);
                    return super.parseIQ(parser);
                }
            });
            */
    }

    /**
     * Extracts STUN servers from a response from Google Talk containing
     * those servers.
     *
     * @param xml The XML with server data.
     * @return The servers.
     */
    public static Collection<InetSocketAddress> extractStunServers(
        final String xml) {
        LOG.info("Processing XML: {}", xml);
        final Collection<InetSocketAddress> servers =
            new ArrayList<InetSocketAddress>(12);
        final Document doc;
        try {
            doc = XmlUtils.toDoc(xml);
        } catch (final IOException e) {
            LOG.warn("Could not lookup Google STUN servers");
            return Collections.emptyList();
        } catch (final SAXException e) {
            LOG.warn("Could not lookup Google STUN servers");
            return Collections.emptyList();
        }
        final XPathUtils xpath = XPathUtils.newXPath(doc);
        final String str = "/iq/query/stun/server";
        try {
            final NodeList nodes = xpath.getNodes(str);
            for (int i = 0; i < nodes.getLength(); i++) {
                final Node node = nodes.item(i);

                final NamedNodeMap nnm = node.getAttributes();
                final Node hostNode = nnm.getNamedItem("host");
                final Node portNode = nnm.getNamedItem("udp");
                if (hostNode == null || portNode == null) {
                    continue;
                }
                final String host = hostNode.getNodeValue();
                final String port = portNode.getNodeValue();
                if (StringUtils.isBlank(host) || StringUtils.isBlank(port)) {
                    continue;
                }
                servers.add(new InetSocketAddress(host,Integer.parseInt(port)));
            }
            LOG.info("Returning servers...");
            return servers;
        } catch (final XPathExpressionException e) {
            LOG.error("XPath error", e);
            throw new Error("Tested XPath no longer working: "+str, e);
        }
    }

    public static String extractSdp(final Document doc) {
        return extractXmppProperty(doc, P2PConstants.SDP);
    }

    //public static String extractKey(final Document doc) {
    //    return extractXmppProperty(doc, P2PConstants.SECRET_KEY);
    //}


    public static long extractTransactionId(final Document doc) {
        final String id = extractXmppProperty(doc, P2PConstants.TRANSACTION_ID);
        return Long.parseLong(id);
    }


    public static String extractFrom(final Document doc) {
        final String xml = XmlUtils.toString(doc);
        LOG.info("Got an XMPP message: {}", xml);
        final XPathUtils xpath = XPathUtils.newXPath(doc);
        final String str = "/message/From";
        try {
            return xpath.getString(str);
        } catch (final XPathExpressionException e) {
            throw new Error("Tested XPath no longer working: "+str, e);
        }
    }

    private static String extractXmppProperty(final Document doc,
        final String name) {
        //final String xml = XmlUtils.toString(doc);
        //LOG.info("Got an XMPP message: {}", xml);
        final XPathUtils xpath = XPathUtils.newXPath(doc);
        final String str =
            "/message/properties/property[name='"+name+"']/value";
        try {
            return xpath.getString(str);
        } catch (final XPathExpressionException e) {
            throw new Error("Tested XPath no longer working: "+str, e);
        }
    }

    public static void printMessage(final Packet msg) {
        LOG.info(toString(msg));
    }

    public static String toString(final Packet msg) {
        final XMPPError error = msg.getError();
        final StringBuilder sb = new StringBuilder();
        sb.append("\nMESSAGE: ");
        sb.append("\nBODY: ");
        if (msg instanceof Message) {
            sb.append(((Message)msg).getBody());
        }
        sb.append("\nFROM: ");
        sb.append(msg.getFrom());
        sb.append("\nTO: ");
        sb.append(msg.getTo());
        sb.append("\nSUBJECT: ");
        if (msg instanceof Message) {
            sb.append(((Message)msg).getSubject());
        }
        sb.append("\nPACKET ID: ");
        sb.append(msg.getPacketID());

        sb.append("\nERROR: ");
        if (error != null) {
            sb.append(error);
            sb.append("\nCODE: ");
            sb.append(error.getCode());
            sb.append("\nMESSAGE: ");
            sb.append(error.getMessage());
            sb.append("\nCONDITION: ");
            sb.append(error.getCondition());
            sb.append("\nEXTENSIONS: ");
            sb.append(error.getExtensions());
            sb.append("\nTYPE: ");
            sb.append(error.getType());
        }
        sb.append("\nEXTENSIONS: ");
        sb.append(msg.getExtensions());
        sb.append("\nTYPE: ");
        if (msg instanceof Message) {
            sb.append(((Message)msg).getType());
        }
        sb.append("\nPROPERTY NAMES: ");
        sb.append(msg.getPropertyNames());
        return sb.toString();
    }


    private static final Map<String, XMPPConnection> xmppConnections =
        new ConcurrentHashMap<String, XMPPConnection>();

    static XMPPConnection persistentXmppConnection(final String username,
            final String password, final String id) throws IOException,
            CredentialException {
        return persistentXmppConnection(username, password, id, 4);
    }

    public static XMPPConnection persistentXmppConnection(final String username,
        final String password, final String id, final int attempts)
        throws IOException, CredentialException {
        return persistentXmppConnection(username, password, id, attempts,
            "talk.google.com", 5222, "gmail.com", null);
    }

    public static XMPPConnection persistentXmppConnection(final String username,
        final String password, final String id, final int attempts,
        final String host, final int port, final String serviceName,
        final XmppP2PClient clientListener)
            throws IOException, CredentialException {
        return persistentXmppConnection(
            new PasswordCredentials(username, password, id),
            attempts, host, port, serviceName, clientListener);
    }

    public static XMPPConnection persistentXmppConnection(
        final XmppCredentials credentials, final int attempts,
        final String host, final int port, final String serviceName,
        final XmppP2PClient clientListener)
            throws IOException, CredentialException {
        final String key = credentials.getKey();
        if (xmppConnections.containsKey(key)) {
            final XMPPConnection conn = xmppConnections.get(key);
            if (isEstablished(conn)) {
                LOG.info("Returning existing xmpp connection");
                return conn;
            } else {
                LOG.info("Removing stale connection");
                xmppConnections.remove(key);
            }
        }
        XMPPException exc = null;
        final XmppConnectionRetyStrategy strategy = XmppConfig.newRetyStrategy();
        while (strategy.retry()) {
            try {
                LOG.debug("Attempting XMPP connection...");
                final XMPPConnection conn =
                    singleXmppConnection(credentials, host, port,
                        serviceName, clientListener);

                LOG.debug("Created offerer");
                xmppConnections.put(key, conn);
                return conn;
            } catch (final XMPPException e) {
                LOG.error("Error creating XMPP connection", e);
                exc = e;
            }

            // Gradual backoff.
            strategy.sleep();
        }
        if (exc != null) {
            throw new IOException("Could not log in!!", exc);
        }
        else {
            throw new IOException("Could not log in?");
        }
    }

    private static boolean isEstablished(final XMPPConnection conn) {
        return conn.isAuthenticated() && conn.isConnected();
    }

    private static InetAddress getHost(final String host) throws IOException {
        return VerifiedAddressFactory.newVerifiedInetAddress(host,
            XmppConfig.isUseDnsSec());
    }

    public static void setGlobalConfig(final ConnectionConfiguration config) {
        XmppUtils.globalConfig = config;
    }

    public static ConnectionConfiguration getGlobalConfig() {
        return XmppUtils.globalConfig;
    }
    
    public static void setGlobalProxyConfig(final ConnectionConfiguration config) {
        XmppUtils.globalProxyConfig = config;
    }

    public static ConnectionConfiguration getGlobalProxyConfig() {
        return XmppUtils.globalProxyConfig;
    }

    private static ExecutorService connectors = Executors.newCachedThreadPool(
        new ThreadFactory() {
            private int count = 0;
            @Override
            public Thread newThread(Runnable r) {
                final Thread t = new Thread(r, "XMPP-Connecting-Thread-"+count);
                t.setDaemon(true);
                count++;
                return t;
            }
        });

    public static XMPPConnection simpleGoogleTalkConnection(
        final String username, final String password, final String id)
        throws CredentialException, XMPPException, IOException {
        return simpleGoogleTalkConnection(
            new PasswordCredentials(username, password, id));
    }

    public static XMPPConnection simpleGoogleTalkConnection(
        final XmppCredentials credentials)
        throws CredentialException, XMPPException, IOException {
        return singleXmppConnection(credentials, "talk.google.com",
            5222, "gmail.com", null);
    }
    
    private static XMPPConnection singleXmppConnection(
        final XmppCredentials credentials, final String xmppServerHost,
        final int xmppServerPort, final String xmppServiceName,
        final XmppP2PClient clientListener) throws XMPPException, IOException,
        CredentialException {
        LOG.debug("Creating single connection with direct config...");
        final InetAddress server = getHost(xmppServerHost);
        final ConnectionConfiguration config;
        if (getGlobalConfig() != null) {
            config = getGlobalConfig();
        } else {
            config = newConfig(server, xmppServerPort, xmppServiceName);
        }
        return singleXmppConnection(credentials, xmppServerHost, xmppServerPort, 
                xmppServiceName, clientListener, config);
    }

    private static XMPPConnection singleXmppConnection(
        final XmppCredentials credentials, final String xmppServerHost,
        final int xmppServerPort, final String xmppServiceName,
        final XmppP2PClient clientListener, 
        final ConnectionConfiguration config) throws XMPPException, IOException,
        CredentialException {
        LOG.debug("Creating single connection...");
        final Future<XMPPConnection> fut =
            connectors.submit(new Callable<XMPPConnection>() {
            @Override
            public XMPPConnection call() throws Exception {
                return newConnection(credentials, config, clientListener);
            }
        });
        try {
            final XMPPConnection conn = fut.get(60, TimeUnit.SECONDS);
            // Make sure we signify gchat support.
            XmppUtils.getSharedStatus(conn);
            return conn;
        } catch (final InterruptedException e) {
            LOG.debug("Interrupted exception", e);
            throw new IOException("Interrupted during login!!", e);
        } catch (final ExecutionException e) {
            LOG.debug("Execution error connecting", e);
            final Throwable cause = e.getCause();
            LOG.debug("Cause", cause);
            LOG.debug("Cause class: " + cause.getClass());
            if (cause instanceof XMPPException) {
                LOG.debug("Processing XMPPException...");
                final String msg = cause.getMessage();
                if (msg.startsWith("XMPPError connecting")) {
                //final Throwable xmppCause = cause.getCause();
                //LOG.info("xmppCause class: " + xmppCause.getClass());
                //if (xmppCause instanceof IOException) {
                    LOG.debug("Trying backup server with XMPPException...");
                    return singleXmppConnection(credentials, xmppServerHost, 
                        xmppServerPort, xmppServiceName, clientListener, 
                        getProxyConfig(config, cause));
                } 
                /*
                if (xmppCause instanceof XMPPException) {
                    LOG.debug("Trying backup server with XMPPException...");
                    return singleXmppConnection(credentials, xmppServerHost, 
                        xmppServerPort, xmppServiceName, clientListener, 
                        getProxyConfig(config, cause));
                }*/
                else {
                    throw (XMPPException)cause;
                }
            } else if (cause instanceof IOException) {
                // If we can't connect, we should try our backup proxy if it 
                // exists.
                LOG.debug("Trying backup server...");
                return singleXmppConnection(credentials, xmppServerHost, 
                    xmppServerPort, xmppServiceName, clientListener, 
                    getProxyConfig(config, cause));
            } else if (cause instanceof IllegalStateException) {
                // This happens in Smack internally when it tries to add a 
                // connection listener to an unconnected XMPP connection.
                // See Connection.java
                LOG.debug("Trying backup server...");
                return singleXmppConnection(credentials, xmppServerHost, 
                    xmppServerPort, xmppServiceName, clientListener, 
                    getProxyConfig(config, cause));
            } else if (cause instanceof CredentialException) {
                throw (CredentialException)cause;
            } else {
                throw new IllegalStateException ("Unrecognized cause", cause);
            }
        } catch (final TimeoutException e) {
            LOG.info("Timeout exception", e);
            throw new IOException("Took too long to login!!", e);
        }
    }

    private static ConnectionConfiguration getProxyConfig(
        final ConnectionConfiguration config, final Throwable t) 
        throws IOException {
        if (config.getProxy().getProxyType() == ProxyType.HTTP) {
            LOG.debug("Config has proxy -- already tried proxy: {}");//, 
                //config.getProxy().getProxyAddress()+":"+config.getProxy().getProxyPort());
            throw new IOException("Already tried proxy", t);
        }
        final ConnectionConfiguration proxyConfig = 
            getGlobalProxyConfig();
        if (proxyConfig == null) {
            LOG.debug("Null global proxy config");
            throw new IOException("Could not use backup proxy", t);
        } 
        if (proxyConfig.getProxy() == null) {
            LOG.debug("Null proxy in global proxy config");
            throw new IOException("Proxy config has no proxy!", t);
        }
        LOG.debug("Returning proxy config");
        return proxyConfig;
    }

    /**
     * Creates a generic XMPP configuration. Note that in practice callers
     * will typically include their own global configuration for things
     * like trust managers, and this method will NOT BE CALLED.
     */
    private static ConnectionConfiguration newConfig(final InetAddress server,
        final int xmppServerPort, final String xmppServiceName) {
        final ConnectionConfiguration config =
            new ConnectionConfiguration(server.getHostAddress(),
                xmppServerPort, xmppServiceName);
        config.setExpiredCertificatesCheckEnabled(true);
        config.setNotMatchingDomainCheckEnabled(true);
        config.setSendPresence(false);

        config.setCompressionEnabled(true);

        //config.setRosterLoadedAtLogin(true);
        config.setReconnectionAllowed(false);

        config.setVerifyChainEnabled(true);

        // This is commented out because the Google Talk signing cert is not
        // trusted by java by default.
        //config.setVerifyRootCAEnabled(true);
        config.setSelfSignedCertificateEnabled(false);

        config.setSocketFactory(new SocketFactory() {

            @Override
            public Socket createSocket(final InetAddress host, final int port,
                final InetAddress localHost, final int localPort)
                throws IOException {
                // We ignore the local port binding.
                return createSocket(host, port);
            }

            @Override
            public Socket createSocket(final String host, final int port,
                final InetAddress localHost, final int localPort)
                throws IOException, UnknownHostException {
                // We ignore the local port binding.
                return createSocket(host, port);
            }

            @Override
            public Socket createSocket(final InetAddress host, final int port)
                throws IOException {
                LOG.info("Creating socket");
                final Socket sock = new Socket();
                sock.connect(new InetSocketAddress(host, port), 40000);
                LOG.info("Socket connected");
                return sock;
            }

            @Override
            public Socket createSocket(final String host, final int port)
                throws IOException, UnknownHostException {
                LOG.info("Creating socket");
                return createSocket(InetAddress.getByName(host), port);
            }
        });
        return config;
    }

    private interface ConnectionHandler {
        void setupConnection(XMPPConnection conn);
        void login(XMPPConnection conn) throws XMPPException;
    }

    private static XMPPConnection newConnection(
        final XmppCredentials credentials,
        final ConnectionConfiguration config,
        final XmppP2PClient clientListener)
        throws XMPPException, CredentialException {
        config.setSecurityMode(SecurityMode.required);
        //config.setSecurityMode(SecurityMode.disabled);
        final XMPPConnection conn = credentials.createConnection(config);
        conn.connect();
        conn.addConnectionListener(new ConnectionListener() {

            @Override
            public void reconnectionSuccessful() {
                LOG.debug("Reconnection successful...");
            }

            @Override
            public void reconnectionFailed(final Exception e) {
                LOG.debug("Reconnection failed", e);
            }

            @Override
            public void reconnectingIn(final int time) {
                LOG.debug("Reconnecting to XMPP server in "+time);
            }

            @Override
            public void connectionClosedOnError(final Exception e) {
                LOG.warn("XMPP connection closed on error", e);
                handleClose();
            }

            @Override
            public void connectionClosed() {
                LOG.debug("XMPP connection closed. Creating new connection.");
                handleClose();
            }

            private void handleClose() {
                if (clientListener != null) {
                    clientListener.handleClose();
                }
            }
        });

        LOG.debug("Connection is Secure: {}", conn.isSecureConnection());
        LOG.debug("Connection is TLS: {}", conn.isUsingTLS());

        try {
            credentials.login(conn);
        } catch (final XMPPException e) {
            //conn.disconnect();
            final String msg = e.getMessage();
            if (msg != null && msg.contains("No response from the server")) {
                // This isn't necessarily a credentials issue -- try to catch
                // non-credentials issues whenever we can.
                throw e;
            }
            LOG.debug("Credentials error!", e);
            throw new CredentialException("Authentication error");
        }

        while (!isEstablished(conn)) {
            LOG.debug("Waiting for authentication");
            try {
                Thread.sleep(80);
            } catch (final InterruptedException e1) {
                LOG.error("Exception during sleep?", e1);
            }
        }

        LOG.debug("Returning connection...");
        return conn;
    }

    public static String jidToUser(final String jid) {
        return StringUtils.substringBefore(jid, "/");
    }

    public static String jidToUser(final XMPPConnection conn) {
        return jidToUser(conn.getUser());
    }

    public static VCard getVCard(final XMPPConnection conn,
        final String emailId) throws XMPPException {
        final VCard card = new VCard();
        card.load(conn, emailId);
        return card;
    }

    //// The following includes a whole bunch of custom Google Talk XMPP
    //// messages.

    public static Packet goOffTheRecord(final String jidToOtr,
        final XMPPConnection conn) {
        LOG.debug("Activating OTR for {}...", jidToOtr);
        final String query =
            "<query xmlns='google:nosave'>"+
                "<item xmlns='google:nosave' jid='"+jidToOtr+"' value='enabled'/>"+
             "</query>";
        return setGTalkProperty(conn, query);
    }

    public static Packet goOnTheRecord(final String jidToOtr,
        final XMPPConnection conn) {
        LOG.debug("Activating OTR for {}...", jidToOtr);
        final String query =
            "<query xmlns='google:nosave'>"+
                "<item xmlns='google:nosave' jid='"+jidToOtr+"' value='disabled'/>"+
             "</query>";
        return setGTalkProperty(conn, query);
    }

    public static Packet getOtr(final XMPPConnection conn) {
        LOG.debug("Getting OTR status...");
        return getGTalkProperty(conn, "<query xmlns='google:nosave'/>");
    }

    public static Packet getSharedStatus(final XMPPConnection conn) {
        LOG.debug("Getting shared status...");
        return getGTalkProperty(conn,
            "<query xmlns='google:shared-status' version='2'/>");
    }

    public static RosterPacket extendedRoster(final XMPPConnection conn) {
        LOG.debug("Requesting extended roster");
        final String query =
            "<query xmlns:gr='google:roster' gr:ext='2' xmlns='jabber:iq:roster'/>";
        return (RosterPacket) getGTalkProperty(conn, query);
    }

    public static Collection<InetSocketAddress> googleStunServers(
        final XMPPConnection conn) {
        LOG.debug("Getting Google STUN servers...");
        final Packet pack =
            getGTalkProperty(conn, "<query xmlns='google:jingleinfo'/>");
        if (pack == null) {
            LOG.warn("Did not get response to Google stun server request!");
            return Collections.emptyList();
        }
        return extractStunServers(pack.toXML());
    }

    public static Packet discoveryRequest(final XMPPConnection conn) {
        LOG.debug("Sending discovery request...");
        return getGTalkProperty(conn,
            "<query xmlns='http://jabber.org/protocol/disco#info'/>");
    }

    private static Packet setGTalkProperty(final XMPPConnection conn,
        final String query) {
        return sendXmppMessage(conn, query, Type.SET);
    }

    private static Packet getGTalkProperty(final XMPPConnection conn,
        final String query) {
        return sendXmppMessage(conn, query, Type.GET);
    }

    private static Packet sendXmppMessage(final XMPPConnection conn,
        final String query, final Type iqType) {

        LOG.debug("Sending XMPP stanza message...");
        final IQ iq = new IQ() {
            @Override
            public String getChildElementXML() {
                return query;
            }
        };
        final String jid = conn.getUser();
        iq.setTo(jidToUser(jid));
        iq.setFrom(jid);
        iq.setType(iqType);
        final PacketCollector collector = conn.createPacketCollector(
            new PacketIDFilter(iq.getPacketID()));

        LOG.debug("Sending XMPP stanza packet:\n"+iq.toXML());
        conn.sendPacket(iq);
        final Packet response = collector.nextResult(40000);
        return response;
    }

    /**
     * Note we don't even need to set this property to maintain compatibility
     * with Google Talk presence -- just sending them the shared status
     * message signifies we generally understand the protocol and allows us
     * to not clobber other clients' presences.
     * @param conn
     * @param to
     */
    public static void setGoogleTalkInvisible(final XMPPConnection conn,
        final String to) {
        final IQ iq = new IQ() {
            @Override
            public String getChildElementXML() {
                return "<query xmlns='google:shared-status' version='2'><invisible value='true'/></query>";
            }
        };
        iq.setType(Type.SET);
        iq.setTo(to);
        LOG.debug("Setting invisible with XML packet:\n"+iq.toXML());
        conn.sendPacket(iq);
    }
}
