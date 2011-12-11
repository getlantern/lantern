package org.lantern;

import java.awt.Desktop;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.UnsupportedEncodingException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.NetworkInterface;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketAddress;
import java.net.SocketException;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.UnknownHostException;
import java.nio.ByteBuffer;
import java.nio.channels.DatagramChannel;
import java.nio.channels.UnresolvedAddressException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.Enumeration;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.Queue;
import java.util.Random;
import java.util.Set;
import java.util.TreeSet;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.httpclient.URIException;
import org.apache.commons.io.IOExceptionWithCause;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.SystemUtils;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpMessage;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.packet.Packet;
import org.json.simple.JSONArray;
import org.lastbamboo.common.offer.answer.NoAnswerException;
import org.lastbamboo.common.p2p.P2PClient;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.littleshoot.proxy.ProxyUtils;
import org.littleshoot.util.ByteBufferUtils;
import org.littleshoot.util.Sha1;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Utility methods for use with Lantern.
 */
public class LanternUtils {

    private static final Logger LOG = 
        LoggerFactory.getLogger(LanternUtils.class);
    
    private static String MAC_ADDRESS;
    
    private static final File CONFIG_DIR = 
        new File(System.getProperty("user.home"), ".lantern");
    
    private static final File DATA_DIR;
    
    private static final File LOG_DIR;
    
    private static final File PROPS_FILE =
        new File(CONFIG_DIR, "lantern.properties");
    
    private static final Properties PROPS = new Properties();
    
    static {
        
        if (SystemUtils.IS_OS_WINDOWS) {
            //logDirParent = CommonUtils.getDataDir();
            DATA_DIR = new File(System.getenv("APPDATA"), "Lantern");
            LOG_DIR = new File(DATA_DIR, "logs");
        } else if (SystemUtils.IS_OS_MAC_OSX) {
            final File homeLibrary = 
                new File(System.getProperty("user.home"), "Library");
            DATA_DIR = CONFIG_DIR;//new File(homeLibrary, "Logs");
            final File allLogsDir = new File(homeLibrary, "Logs");
            LOG_DIR = new File(allLogsDir, "Lantern");
        } else {
            DATA_DIR = new File(SystemUtils.getUserHome(), ".lantern");
            LOG_DIR = new File(DATA_DIR, "logs");
        }

        if (!DATA_DIR.isDirectory()) {
            if (!DATA_DIR.mkdirs()) {
                System.err.println("Could not create parent at: "
                        + DATA_DIR);
            }
        }
        if (!LOG_DIR.isDirectory()) {
            if (!LOG_DIR.mkdirs()) {
                System.err.println("Could not create dir at: " + LOG_DIR);
            }
        }
        if (!CONFIG_DIR.isDirectory()) {
            if (!CONFIG_DIR.mkdirs()) {
                LOG.error("Could not make config directory at: "+CONFIG_DIR);
            }
        } 
        
        if (!PROPS_FILE.isFile()) {
            try {
                if (!PROPS_FILE.createNewFile()) {
                    LOG.error("Could not create props file!!");
                }
            } catch (final IOException e) {
                LOG.error("Could not create props file!!", e);
            }
        }
        
        InputStream is = null;
        try {
            is = new FileInputStream(PROPS_FILE);
            PROPS.load(is);
        } catch (final IOException e) {
            LOG.error("Error loading props file: "+PROPS_FILE, e);
        } finally {
            IOUtils.closeQuietly(is);
        }
    }
    
    public static final ClientSocketChannelFactory clientSocketChannelFactory =
        new NioClientSocketChannelFactory(
            Executors.newCachedThreadPool(),
            Executors.newCachedThreadPool());
    
    
    /**
     * Helper method that ensures all written requests are properly recorded.
     * 
     * @param request The request.
     */
    public static void writeRequest(final Queue<HttpRequest> httpRequests,
        final HttpRequest request, final ChannelFuture cf) {
        httpRequests.add(request);
        LOG.info("Writing request: {}", request);
        LanternUtils.genericWrite(request, cf);
    }
    
    public static void genericWrite(final Object message, 
        final ChannelFuture future) {
        final Channel ch = future.getChannel();
        if (ch.isConnected()) {
            ch.write(message);
        } else {
            future.addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(final ChannelFuture cf) 
                    throws Exception {
                    if (cf.isSuccess()) {
                        ch.write(message);
                    }
                }
            });
        }
    }
    
    public static Socket openRawOutgoingPeerSocket(
        final URI uri, final P2PClient p2pClient,
        final Map<URI, AtomicInteger> peerFailureCount) throws IOException {
        return openOutgoingPeerSocket(uri, p2pClient, peerFailureCount, true);
    }
    
    public static Socket openOutgoingPeerSocket(
        final URI uri, final P2PClient p2pClient,
        final Map<URI, AtomicInteger> peerFailureCount) throws IOException {
        return openOutgoingPeerSocket(uri, p2pClient, peerFailureCount, false);
    }
    
    public static Socket openOutgoingPeerSocket(
        final URI uri, final P2PClient p2pClient,
        final Map<URI, AtomicInteger> peerFailureCount,
        final boolean raw) throws IOException {

        // Start the connection attempt.
        try {
            LOG.info("Creating a new socket to {}", uri);
            final Socket sock;
            if (raw) {
                sock = p2pClient.newRawSocket(uri);
            } else {
                sock = p2pClient.newSocket(uri);
            }
            LOG.info("Got outgoing peer socket: {}", sock);
            //startReading(sock, browserToProxyChannel, recordStats);
            return sock;
        } catch (final NoAnswerException nae) {
            // This is tricky, as it can mean two things. First, it can mean
            // the XMPP message was somehow lost. Second, it can also mean
            // the other side is actually not there and didn't respond as a
            // result.
            LOG.info("Did not get answer!! Closing channel from browser", nae);
            final AtomicInteger count = peerFailureCount.get(uri);
            if (count == null) {
                LOG.info("Incrementing failure count");
                peerFailureCount.put(uri, new AtomicInteger(0));
            }
            else if (count.incrementAndGet() > 5) {
                LOG.info("Got a bunch of failures in a row to this peer. " +
                    "Removing it.");
                
                // We still reset it back to zero. Note this all should 
                // ideally never happen, and we should be able to use the
                // XMPP presence alerts to determine if peers are still valid
                // or not.
                peerFailureCount.put(uri, new AtomicInteger(0));
                //proxyStatusListener.onCouldNotConnectToPeer(uri);
            } 
            throw new IOExceptionWithCause(nae);
        } catch (final IOException ioe) {
            //proxyStatusListener.onCouldNotConnectToPeer(uri);
            LOG.warn("Could not connect to peer", ioe);
            throw ioe;
        }
    }
    
    public static void startReading(final Socket sock, final Channel channel, 
        final boolean recordStats) {
        final Runnable runner = new Runnable() {
            @Override
            public void run() {
                final byte[] buffer = new byte[4096];
                long count = 0;
                int n = 0;
                try {
                    final InputStream is = sock.getInputStream();
                    while (-1 != (n = is.read(buffer))) {
                        //LOG.info("Writing response data: {}", new String(buffer, 0, n));
                        // We need to make a copy of the buffer here because
                        // the writes are asynchronous, so the bytes can
                        // otherwise get scrambled.
                        final ChannelBuffer buf =
                            ChannelBuffers.copiedBuffer(buffer, 0, n);
                        channel.write(buf);
                        if (recordStats) {
                            LanternHub.statsTracker().addBytesProxied(n, sock);
                        }
                        count += n;
                        
                    }
                    ProxyUtils.closeOnFlush(channel);

                } catch (final IOException e) {
                    LOG.info("Exception relaying peer data back to browser",e);
                    ProxyUtils.closeOnFlush(channel);
                    
                    // The other side probably just closed the connection!!
                    
                    //channel.close();
                    //proxyStatusListener.onError(peerUri);
                    
                }
            }
        };
        final Thread peerReadingThread = 
            new Thread(runner, "Peer-Data-Reading-Thread");
        peerReadingThread.setDaemon(true);
        peerReadingThread.start();
    }
    
    public static String getMacAddress() {
        if (MAC_ADDRESS != null) {
            LOG.info("Returning MAC: "+MAC_ADDRESS);
            return MAC_ADDRESS;
        }
        final Enumeration<NetworkInterface> nis;
        try {
            nis = NetworkInterface.getNetworkInterfaces();
        } catch (final SocketException e1) {
            throw new Error("Could not read network interfaces?");
        }
        while (nis.hasMoreElements()) {
            final NetworkInterface ni = nis.nextElement();
            try {
                if (!ni.isUp()) {
                    LOG.info("Ignoring interface that's not up: {}", 
                        ni.getDisplayName());
                    continue;
                }
                final byte[] mac = ni.getHardwareAddress();
                if (mac != null && mac.length > 0) {
                    LOG.info("Returning 'normal' MAC address");
                    return macMe(mac);
                }
            } catch (final SocketException e) {
                LOG.warn("Could not get MAC address?");
            }
        }
        try {
            LOG.warn("Returning custom MAC address");
            return macMe(InetAddress.getLocalHost().getHostAddress() + 
                    System.currentTimeMillis());
        } catch (final UnknownHostException e) {
            final byte[] bytes = new byte[24];
            new Random().nextBytes(bytes);
            return macMe(bytes);
        }
    }

    private static String macMe(final String mac) {
        return macMe(utf8Bytes(mac));
    }

    public static byte[] utf8Bytes(final String str) {
        try {
            return str.getBytes("UTF-8");
        } catch (final UnsupportedEncodingException e) {
            LOG.error("No UTF-8?", e);
            throw new RuntimeException("No UTF-8?", e);
        }
    }

    private static String macMe(final byte[] mac) {
        final MessageDigest md = new Sha1();
        md.update(mac);
        final byte[] raw = md.digest();
        MAC_ADDRESS = Base64.encodeBase64URLSafeString(raw);
        return MAC_ADDRESS;
    }

    public static File configDir() {
        return CONFIG_DIR;
    }
    

    public static File dataDir() {
        return DATA_DIR;
    }
    
    public static File logDir() {
        return LOG_DIR;
    }
    
    public static File propsFile() {
        return PROPS_FILE;
    }
    
    public static boolean isTransferEncodingChunked(final HttpMessage m) {
        final List<String> chunked = 
            m.getHeaders(HttpHeaders.Names.TRANSFER_ENCODING);
        if (chunked.isEmpty()) {
            return false;
        }

        for (String v: chunked) {
            if (v.equalsIgnoreCase(HttpHeaders.Values.CHUNKED)) {
                return true;
            }
        }
        return false;
    }

    public static JSONArray toJsonArray(final Collection<String> strs) {
        final JSONArray json = new JSONArray();
        synchronized (strs) {
            json.addAll(strs);
        }
        return json;
    }
    
    public static boolean isConfigured() {
        if (!PROPS_FILE.isFile()) {
            return false;
        }
        final Properties props = new Properties();
        InputStream is = null;
        try {
            is = new FileInputStream(PROPS_FILE);
            props.load(is);
            final String un = props.getProperty("google.user");
            final String pwd = props.getProperty("google.pwd");
            return (StringUtils.isNotBlank(un) && StringUtils.isNotBlank(pwd));
        } catch (final IOException e) {
            LOG.error("Error loading props file: "+PROPS_FILE, e);
        } finally {
            IOUtils.closeQuietly(is);
        }
        return false;
    }
    
    public static Collection<RosterEntry> getRosterEntries(final String email,
        final String pwd, final int attempts) throws IOException {
        final XMPPConnection conn = 
            XmppUtils.persistentXmppConnection(email, pwd, "lantern", attempts);
        final Roster roster = conn.getRoster();
        final Collection<RosterEntry> unordered = roster.getEntries();
        final Comparator<RosterEntry> comparator = new Comparator<RosterEntry>() {
            @Override
            public int compare(final RosterEntry re1, final RosterEntry re2) {
                final String name1 = re1.getName();
                final String name2 = re2.getName();
                if (name1 == null) {
                    return 1;
                } else if (name2 == null) {
                    return -1;
                }
                return name1.compareToIgnoreCase(name2);
            }
        };
        final Collection<RosterEntry> entries = 
            new TreeSet<RosterEntry>(comparator);
        for (final RosterEntry entry : unordered) {
            entries.add(entry);
        }
        return entries;
    }
    
    public static Collection<String> getProxies() {
        final String proxies = getStringProperty("proxies");
        if (StringUtils.isBlank(proxies)) {
            return Collections.emptySet();
        } else {
            final String[] all = proxies.split(",");
            return Arrays.asList(all);
        }
    }

    public static void addProxy(final String server) {
        String proxies = getStringProperty("proxies");
        
        if (proxies == null) {
            proxies = server;
        } else {
            final Set<String> unique = 
                new LinkedHashSet<String>(Arrays.asList(proxies.split(",")));
            if (unique.contains(server)) {
                return;
            } else {
                unique.add(server);
            }
            final StringBuilder sb = new StringBuilder();
            for (final String proxy : unique) {
                sb.append(proxy.trim());
                sb.append(",");
            }
            proxies = sb.toString();
        }
        setStringProperty("proxies", proxies);
    }
    
    public static void writeCredentials(final String email, final String pwd) {
        LOG.info("Writing credentials...");
        PROPS.setProperty("google.user", email);
        PROPS.setProperty("google.pwd", pwd);
        persistProps();
    }
    

    public static void clearCredentials() {
        LOG.info("Clearing credentials...");
        PROPS.remove("google.user");
        PROPS.remove("google.pwd");
        persistProps();
    }

    public static boolean newInstall() {
        return getBooleanProperty("newInstall");
    }
    
    public static void installed() {
        setBooleanProperty("newInstall", false);
    }

    public static void setBooleanProperty(final String key, 
        final boolean value) {
        PROPS.setProperty(key, String.valueOf(value));
        persistProps();
    }

    public static boolean getBooleanProperty(final String key) {
        final String val = PROPS.getProperty(key);
        if (StringUtils.isBlank(val)) {
            return false;
        }
        LOG.info("Checking property: {}", val);
        return "true".equalsIgnoreCase(val.trim());
    }
    
    public static void setStringProperty(final String key, final String value) {
        PROPS.setProperty(key, value);
        persistProps();
    }

    public static String getStringProperty(final String key) {
        return PROPS.getProperty(key);
    }

    public static void clear(final String key) {
        PROPS.remove(key);
        persistProps();
    }

    private static void persistProps() {
        FileWriter fw = null;
        try {
            fw = new FileWriter(PROPS_FILE);
            PROPS.store(fw, "");
        } catch (final IOException e) {
            LOG.error("Could not store props?");
        } finally {
            IOUtils.closeQuietly(fw);
        }
    }
    
    /**
     * We subclass here purely to expose the encoding method of the built-in
     * request encoder.
     */
    private static final class RequestEncoder extends HttpRequestEncoder {
        private ChannelBuffer encode(final HttpRequest request, 
            final Channel ch) throws Exception {
            return (ChannelBuffer) super.encode(null, ch, request);
        }
    }

    public static byte[] toByteBuffer(final HttpRequest request,
        final ChannelHandlerContext ctx) throws Exception {
        // We need to convert the Netty message to raw bytes for sending over
        // the socket.
        final RequestEncoder encoder = new RequestEncoder();
        final ChannelBuffer cb = encoder.encode(request, ctx.getChannel());
        return toRawBytes(cb);
    }

    public static byte[] toRawBytes(final ChannelBuffer cb) {
        final ByteBuffer buf = cb.toByteBuffer();
        return ByteBufferUtils.toRawBytes(buf);
    }

    public static Collection<String> toHttpsCandidates(final String uriStr) {
        final Collection<String> segments = new LinkedHashSet<String>();
        try {
            final org.apache.commons.httpclient.URI uri = 
                new org.apache.commons.httpclient.URI(uriStr, false);
            final String host = uri.getHost();
            //LOG.info("Using host: {}", host);
            segments.add(host);
            final String[] segmented = host.split("\\.");
            //LOG.info("Testing segments: {}", Arrays.asList(segmented));
            for (int i = 0; i < segmented.length; i++) {
                final String tmp = segmented[i];
                segmented[i] = "*";
                final String segment = StringUtils.join(segmented, '.');
                //LOG.info("Adding segment: {}", segment);
                segments.add(segment);
                segmented[i] = tmp;
            }
            
            for (int i = 1; i < segmented.length - 1; i++) {
                final String segment = 
                    "*." + StringUtils.join(segmented, '.', i, segmented.length);//segmented.slice(i,segmented.length).join(".");
                //LOG.info("Checking segment: {}", segment);
                segments.add(segment);
            }
        } catch (final URIException e) {
            LOG.error("Could not create URI?", e);
        }
        return segments;
    }

    public static void waitForInternet() {
        while (true) {
            try {
                final DatagramChannel channel = DatagramChannel.open();
                final SocketAddress server = 
                    new InetSocketAddress("time-a.nist.gov", 37);
                channel.connect(server);
                return;
            } catch (final IOException e) {
            } catch (final UnresolvedAddressException e) {
            }
            try {
                Thread.sleep(250);
            } catch (final InterruptedException e) {
                LOG.error("Interrupted?", e);
            }
        }
    }
    
    public static int randomPort() {
        final SecureRandom sr = LanternHub.secureRandom();
        for (int i = 0; i < 10; i++) {
            final int randomPort = 1024 + (Math.abs(sr.nextInt()) % 60000);
            try {
                final ServerSocket sock = new ServerSocket();
                sock.bind(new InetSocketAddress("127.0.0.1", randomPort));
                final int port = sock.getLocalPort();
                sock.close();
                return port;
            } catch (final IOException e) {
                LOG.info("Could not bind to port: {}", randomPort);
            }
        }
        
        // If we can't grab one of our securely chosen random ports, use
        // whatever port the OS assigns.
        try {
            final ServerSocket sock = new ServerSocket();
            sock.bind(null);
            final int port = sock.getLocalPort();
            sock.close();
            return port;
        } catch (final IOException e) {
            LOG.info("Still could not bind?");
            return 1024 + (Math.abs(sr.nextInt()) % 60000);
        }
    }
    
    /** 
     * Execute keytool, returning the output.
     */
    public static String runKeytool(final String... args) {
        final CommandLine command = new CommandLine(findKeytoolPath(), args);
        command.execute();
        final String output = command.getStdOut();
        if (!command.isSuccessful()) {
            LOG.info("Command failed!! -- {}", args);
        }
        return output;
    }

    private static String findKeytoolPath() {
        final File defaultLocation = new File("/usr/bin/keytool");
        if (defaultLocation.exists()) {
            return defaultLocation.getAbsolutePath();
        }
        final String networkSetupBin = CommandLine.findExecutable("keytool");
        if (networkSetupBin != null) {
            return networkSetupBin;
        }
        LOG.error("Could not fine keytool?!?!?!?");
        return null;
    }

    private static final boolean RUN_WITH_UI =
        LanternUtils.getBooleanProperty("linuxui");
    
    public static boolean runWithUi() {
        if (!settingExists("linuxui")) {
            return true;
        }
        return RUN_WITH_UI;
    }

    private static boolean settingExists(final String key) {
        return PROPS.containsKey(key);
    }

    
    public static Packet activateOtr(final XMPPConnection conn) {
        return XmppUtils.goOffTheRecord(LanternConstants.LANTERN_JID, conn);
    }
    
    public static Packet deactivateOtr(final XMPPConnection conn) {
        return XmppUtils.goOnTheRecord(LanternConstants.LANTERN_JID, conn);
    }
    
    public static boolean shouldProxy() {
        return CensoredUtils.isCensored() || CensoredUtils.isForceCensored();
    }
    
    public static void browseUrl(final String uri) {
        if( !Desktop.isDesktopSupported() ) {
            LOG.error("Desktop not supported?");
        }
        final Desktop desktop = Desktop.getDesktop();
        if( !desktop.isSupported(Desktop.Action.BROWSE )) {
            LOG.error("Browse not supported?");
        }
        try {
            desktop.browse(new URI(uri));
        } catch (final IOException e) {
            LOG.warn("Error opening browser", e);
        } catch (final URISyntaxException e) {
            LOG.warn("Could not load URI", e);
        }
    }
}    


