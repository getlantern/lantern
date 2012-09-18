package org.lantern;

import java.awt.Desktop;
import java.io.Console;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOError;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
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
import java.security.GeneralSecurityException;
import java.security.KeyManagementException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.security.Security;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateException;
import java.util.Arrays;
import java.util.Collection;
import java.util.Enumeration;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Queue;
import java.util.Scanner;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.concurrent.ConcurrentSkipListMap;
import java.util.concurrent.atomic.AtomicInteger;

import javax.crypto.Cipher;
import javax.crypto.CipherInputStream;
import javax.crypto.CipherOutputStream;
import javax.net.SocketFactory;
import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLServerSocket;
import javax.net.ssl.SSLServerSocketFactory;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;
import javax.security.auth.login.CredentialException;
import javax.servlet.ServletRequest;
import javax.servlet.http.HttpServletRequest;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.httpclient.URIException;
import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOExceptionWithCause;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.SystemUtils;
import org.apache.commons.lang.math.NumberUtils;
import org.codehaus.jackson.JsonGenerationException;
import org.codehaus.jackson.map.JsonMappingException;
import org.codehaus.jackson.map.ObjectMapper;
import org.codehaus.jackson.map.ObjectWriter;
import org.codehaus.jackson.map.SerializationConfig.Feature;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpMessage;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.packet.Packet;
import org.jivesoftware.smack.packet.RosterPacket;
import org.jivesoftware.smack.packet.RosterPacket.Item;
import org.lantern.SettingsState.State;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.lastbamboo.common.offer.answer.NoAnswerException;
import org.lastbamboo.common.p2p.P2PClient;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.littleshoot.proxy.ProxyUtils;
import org.littleshoot.util.ByteBufferUtils;
import org.littleshoot.util.Sha1;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.io.Files;

/**
 * Utility methods for use with Lantern.
 */
public class LanternUtils {

    public static boolean isDevMode() {
        // TODO make this more robust
        return LanternConstants.VERSION.equals("lantern_version_tok");
    }

    private static String MAC_ADDRESS;
    
    private static final Logger LOG = 
        LoggerFactory.getLogger(LanternUtils.class);
    
    public static String jidToUserId(final String fullId) {
        return fullId.split("/")[0];
    }
    
    public static String jidToInstanceId(final String fullId) {
        return fullId.split("/")[1];
    }
    
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
    
    private static Socket openOutgoingPeerSocket(
        final URI uri, final P2PClient p2pClient,
        final Map<URI, AtomicInteger> peerFailureCount,
        final boolean raw) throws IOException {

        if (p2pClient == null) {
            LOG.info("P2P client is null. Testing?");
            throw new IOException("P2P client not connected");
        }
        
        // Start the connection attempt.
        try {
            LOG.info("Creating a new socket to {}", uri);
            final Socket sock;
            if (raw) {
                sock = p2pClient.newRawSocket(uri);
            } else {
                sock = p2pClient.newSocket(uri);
            }
            
            // Note that it's OK that this prints SSL_NULL_WITH_NULL_NULL --
            // the handshake doesn't actually happen until the first IO, so
            // the SSL ciphers and such should be all null at this point.
            LOG.debug("Got outgoing peer socket {}", sock);
            if (sock instanceof SSLSocket) {
                LOG.debug("Socket has ciphers {}", 
                    ((SSLSocket)sock).getEnabledCipherSuites());
            } else {
                LOG.debug("Not an SSL socket...");
            }
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
                int n = 0;
                try {
                    LOG.info("READING FROM SOCKET: {}", sock);
                    if (sock.isClosed()) {
                        LOG.error("SOCKET IS CLOSED");
                        ProxyUtils.closeOnFlush(channel);
                        return;
                    }
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
                            StatsTracker tracker = LanternHub.statsTracker();
                            tracker.addBytesProxied(n, sock);
                            tracker.addDownBytesViaProxies(n, sock);
                        }
                        
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
            LanternHub.secureRandom().nextBytes(bytes);
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
        // We wrap the MAC in a SHA-1 to avoid distributing actual 
        // MAC addresses.
        final MessageDigest md = new Sha1();
        md.update(mac);
        final byte[] raw = md.digest();
        MAC_ADDRESS = Base64.encodeBase64URLSafeString(raw);
        return MAC_ADDRESS;
    }
    
    
    /**
     * This is the local proxy port data is relayed to on the "server" side
     * of P2P connections.
     * 
     * NOT IN CONSTANTS BECAUSE LanternUtils INITIALIZES THE LOGGER, WHICH
     * CAN'T HAPPEN IN CONSTANTS DUE TO THE CONFIGURATION SEQUENCE IN 
     * PRODUCTION.
     */
    public static final int PLAINTEXT_LOCALHOST_PROXY_PORT = 
        LanternUtils.randomPort();

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
    
    public static boolean isConfigured() {
        if (!LanternConstants.DEFAULT_SETTINGS_FILE.isFile()) {
            LOG.info("No settings file");
            return false;
        }
        final String un = LanternHub.settings().getEmail();
        final String pwd = LanternHub.settings().getPassword();
        return (StringUtils.isNotBlank(un) && StringUtils.isNotBlank(pwd));
    }
    
    public static Collection<LanternRosterEntry> getRosterEntries(
        final String email, final String pwd, final int attempts) 
        throws IOException, CredentialException {
        final XMPPConnection conn = 
            XmppUtils.persistentXmppConnection(email, pwd, "lantern", attempts);
        return getRosterEntries(conn);
    }

    public static Collection<LanternRosterEntry> getRosterEntries(
        final XMPPConnection xmppConnection) {
        final RosterPacket msg = XmppUtils.extendedRoster(xmppConnection);
        return getRosterEntriesByItems(msg.getRosterItems());
    }

    public static Collection<LanternRosterEntry> getRosterEntriesByItems(
        final Collection<Item> unordered) {
        final Collection<LanternRosterEntry> entries = 
            new TreeSet<LanternRosterEntry>();
        for (final Item entry : unordered) {
            final LanternRosterEntry lp = new LanternRosterEntry(entry);
            final boolean added = entries.add(lp);
            if (!added) {
                LOG.warn("DID NOT ADD {}", entry);
                LOG.warn("ENTRIES: {}", entries);
            }
        }
        return entries;
    }

    public static Map<String, LanternRosterEntry> getRosterEntries(
        final Collection<RosterEntry> unordered) {
        final Map<String, LanternRosterEntry> entries = 
            new ConcurrentSkipListMap<String, LanternRosterEntry>();
        for (final RosterEntry entry : unordered) {
            final LanternRosterEntry lp = new LanternRosterEntry(entry);
            entries.put(lp.getEmail(), lp);
        }
        return entries;
    }
    

    public static boolean isLanternHub(final String from) {
        return from.startsWith("lanternctrl@") && 
            from.contains("lanternctrl.appspot");
    }
    

    public static boolean isLanternJid(final String from) {
        // Here's the format we're looking for: "-la-"
        if (from.contains("/"+LanternConstants.UNCENSORED_ID)) {
            LOG.info("Returning Lantern TRUE for from: {}", from);
            return true;
        }
        return false;
    }
    
    public static void writeCredentials(final String email, final String pwd) {
        LOG.info("Writing credentials...");
        LanternHub.settings().setEmail(email);
        LanternHub.settings().setPassword(pwd);
        LanternHub.settings().getSettings().setState(State.SET);
        LanternHub.settingsIo().write();
    }
    

    public static void clearCredentials() {
        LOG.info("Clearing credentials...");
        LanternHub.settings().setEmail("");
        LanternHub.settings().setPassword("");
        LanternHub.settingsIo().write();
    }

    public static boolean isNewInstall() {
        return LanternHub.settings().getSettings().getState() == 
            State.UNSET;
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
            if (hasNetworkConnection()) {
                return;
            }
            try {
                Thread.sleep(50);
            } catch (final InterruptedException e) {
                LOG.error("Interrupted?", e);
            }
        }
    }
    
    public static boolean hasNetworkConnection() {
        // Just try a couple of times to make sure.
        for (int i = 0; i < 2; i++) {
            try {
                final DatagramChannel channel = DatagramChannel.open();
                final SocketAddress server = 
                    new InetSocketAddress("www.google.com", 80);
                channel.connect(server);
                return true;
            } catch (final IOException e) {
            } catch (final UnresolvedAddressException e) {
            }
        }
        return false;
    }

    public static int randomPort() {
        final SecureRandom sr = LanternHub.secureRandom();
        if (LanternConstants.ON_APP_ENGINE) {
            // Can't create server sockets on app engine.
            return -1;
        }
        for (int i = 0; i < 20; i++) {
            // The +1 on the random int is because 
            // Math.abs(Integer.MIN_VALUE) == Integer.MIN_VALUE -- caught
            // by FindBugs.
            final int randomPort = 1024 + (Math.abs(sr.nextInt() + 1) % 60000);
            ServerSocket sock = null;
            try {
                sock = new ServerSocket();
                sock.bind(new InetSocketAddress("127.0.0.1", randomPort));
                final int port = sock.getLocalPort();
                return port;
            } catch (final IOException e) {
                LOG.info("Could not bind to port: {}", randomPort);
            } finally {
                if (sock != null) {
                    try {
                        sock.close();
                    } catch (IOException e) {
                    }
                }
            }
            
        }
        
        // If we can't grab one of our securely chosen random ports, use
        // whatever port the OS assigns.
        ServerSocket sock = null;
        try {
            sock = new ServerSocket();
            sock.bind(null);
            final int port = sock.getLocalPort();
            return port;
        } catch (final IOException e) {
            LOG.info("Still could not bind?");
            return 1024 + (Math.abs(sr.nextInt() + 1) % 60000);
        } finally {
            if (sock != null) {
                try {
                    sock.close();
                } catch (IOException e) {
                }
            }
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

        if (SystemUtils.IS_OS_MAC_OSX) {
            // try to explicitly select the 1.6 keytool -- 
            // The user may have 1.5 selected as the default 
            // javavm (default in os x 10.5.8) 
            // in this case, the default location below will
            // point to the 1.5 keytool instead.
            final File keytool16 = new File(
                "/System/Library/Frameworks/JavaVM.framework/Versions/1.6/Commands/keytool");
            if (keytool16.exists()) {
                return keytool16.getAbsolutePath();
            }
        } 
        final File jh = new File(System.getProperty("java.home"), "bin");
        if (jh.isDirectory()) {
            final String name;
            if (SystemUtils.IS_OS_WINDOWS) {
                name = "keytool.exe";
            } else {
                name = "keytool";
            }
            try {
                return new File(jh, name).getCanonicalPath();
            } catch (final IOException e) {
                LOG.warn("Error getting canonical path: " + jh);
            }
        } else {
            LOG.warn("java.home/bin not a directory? "+jh);
        }
        
        final File defaultLocation = new File("/usr/bin/keytool");
        if (defaultLocation.exists()) {
            return defaultLocation.getAbsolutePath();
        }
        final String networkSetupBin = CommandLine.findExecutable("keytool");
        if (networkSetupBin != null) {
            return networkSetupBin;
        }
        LOG.error("Could not find keytool?!?!?!?");
        return null;
    }
    
    public static Packet activateOtr(final XMPPConnection conn) {
        return XmppUtils.goOffTheRecord(LanternConstants.LANTERN_JID, conn);
    }
    
    public static Packet deactivateOtr(final XMPPConnection conn) {
        return XmppUtils.goOnTheRecord(LanternConstants.LANTERN_JID, conn);
    }
    
    public static void browseUrl(final String uri) {
        if( !Desktop.isDesktopSupported() ) {
            LOG.error("Desktop not supported?");
            LinuxBrowserLaunch.openURL(uri);
            return;
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
    
    public static char[] readPasswordCLI() throws IOException {
        Console console = System.console();
        if (console == null) {
            LOG.info("No console -- using System.in...");
            final Scanner sc = new Scanner(System.in);
            return sc.nextLine().toCharArray();
        }
        try {
            return console.readPassword();
        } catch (final IOError e) {
            throw new IOException("Could not read pass from console", e);
        }
    }
    
    public static String readLineCLI() throws IOException {
        Console console = System.console();
        if (console == null) {
            LOG.info("No console -- using System.in...");
            final Scanner sc = new Scanner(System.in);
            return sc.nextLine();
        }
        try {
            return console.readLine();
        } catch (final IOError e) {
            throw new IOException("Could not read line from console", e);
        }
    }
        
    public static InputStream localDecryptInputStream(final InputStream in) 
        throws IOException, GeneralSecurityException {
        Cipher cipher = 
            LanternHub.localCipherProvider().newLocalCipher(Cipher.DECRYPT_MODE);
        return new CipherInputStream(in, cipher);
    }
    
    public static InputStream localDecryptInputStream(File file) 
        throws IOException, GeneralSecurityException {
        return localDecryptInputStream(new FileInputStream(file));
    }
    
    public static OutputStream localEncryptOutputStream(final OutputStream os)
        throws IOException, GeneralSecurityException {
        Cipher cipher = 
            LanternHub.localCipherProvider().newLocalCipher(Cipher.ENCRYPT_MODE);
        return new CipherOutputStream(os, cipher);
    }
    
    public static OutputStream localEncryptOutputStream(File file) 
        throws IOException, GeneralSecurityException {
        return localEncryptOutputStream(new FileOutputStream(file));
    }
    
    /** 
     * output an encrypted copy of the plaintext file given in the 
     * dest file given. 
     * 
     * @param plainSrc a plaintext source File to copy
     * @param encryptedDest a destination file to write an encrypted copy of 
     * plainSrc to
     */
    public static void localEncryptedCopy(final File plainSrc, 
        final File encryptedDest)
        throws GeneralSecurityException, IOException {
        if (plainSrc.equals(encryptedDest)) {
            throw new IOException("Source and dest cannot be the same file.");
        }
        
        InputStream in = null;
        OutputStream out = null;
        try {
            in = new FileInputStream(plainSrc);
            out = localEncryptOutputStream(encryptedDest);
            IOUtils.copy(in, out);
        } finally {
            IOUtils.closeQuietly(in);
            IOUtils.closeQuietly(out);
        }
    }

    /**
     * output a decrypted copy of the encrypted file given in the 
     * dest file given. 
     * 
     * @param encryptedSrc an encrypted source file to copy
     * @param plainDest a destination file to write a decrypted copy of 
     * encryptedSrc to
     * 
     */
    public static void localDecryptedCopy(final File encryptedSrc, 
        final File plainDest)
        throws GeneralSecurityException, IOException {
        if (encryptedSrc.equals(plainDest)) {
            throw new IOException("Source and dest cannot be the same file.");
        }
        InputStream in = null;
        OutputStream out = null;
        try {
            in = localDecryptInputStream(encryptedSrc);
            out = new FileOutputStream(plainDest);
            IOUtils.copy(in, out);
        } finally {
            IOUtils.closeQuietly(in);
            IOUtils.closeQuietly(out);
        }    
    }

    /**
     * Converts the request arguments to a map of parameter keys to single
     * values, ignoring multiple values.
     * 
     * @param req The request.
     * @return The mapped argument names and values.
     */
    public static Map<String, String> toParamMap(final ServletRequest req) {
        final Map<String, String> map = new TreeMap<String, String>(
                String.CASE_INSENSITIVE_ORDER);
        final Map<String, String[]> paramMap = req.getParameterMap();
        final Set<Entry<String, String[]>> entries = paramMap.entrySet();
        for (final Entry<String, String[]> entry : entries) {
            final String[] values = entry.getValue();
            map.put(entry.getKey(), values[0]);
        }
        return map;
    }

    public static String jsonify(final Object all) {
        
        final ObjectMapper mapper = new ObjectMapper();
        mapper.configure(Feature.INDENT_OUTPUT, true);
        //mapper.configure(Feature.SORT_PROPERTIES_ALPHABETICALLY, false);

        try {
            return mapper.writeValueAsString(all);
        } catch (final JsonGenerationException e) {
            LOG.warn("Error generating JSON", e);
        } catch (final JsonMappingException e) {
            LOG.warn("Error generating JSON", e);
        } catch (final IOException e) {
            LOG.warn("Error generating JSON", e);
        }
        return "";
    }
    
    public static String jsonify(final Object all, final Class<?> view) {
        final ObjectMapper mapper = new ObjectMapper();
        mapper.configure(Feature.INDENT_OUTPUT, true);
        ObjectWriter writer = mapper.writerWithView(view);
        try {
            return writer.writeValueAsString(all);
        } catch (final JsonGenerationException e) {
            LOG.warn("Error generating JSON", e);
        } catch (final JsonMappingException e) {
            LOG.warn("Error generating JSON", e);
        } catch (final IOException e) {
            LOG.warn("Error generating JSON", e);
        }
        return "";
    }
    
    /**
     * Returns <code>true</code> if the specified string is either "true" or
     * "on" ignoring case.
     * 
     * @param val The string in question.
     * @return <code>true</code> if the specified string is either "true" or
     * "on" ignoring case, otherwise <code>false</code>.
     */
    public static boolean isTrue(final String val) {
        return checkTrueOrFalse(val, "true", "on");
    }

    /**
     * Returns <code>true</code> if the specified string is either "false" or
     * "off" ignoring case.
     * 
     * @param val The string in question.
     * @return <code>true</code> if the specified string is either "false" or
     * "off" ignoring case, otherwise <code>false</code>.
     */
    public static boolean isFalse(final String val) {
        return checkTrueOrFalse(val, "false", "off");
    }

    private static boolean checkTrueOrFalse(final String val, 
        final String str1, final String str2) {
        final String str = val.trim();
        return StringUtils.isNotBlank(str) && 
            (str.equalsIgnoreCase(str1) || str.equalsIgnoreCase(str2));
    }

    /**
     * Replaces the first instance of the specified regex in the given file
     * with the replacement string and writes out the new complete file.
     * 
     * @param file The file to modify.
     * @param regex The regular expression to search for.
     * @param replacement The replacement string.
     */
    public static void replaceInFile(final File file, 
        final String regex, final String replacement) {
        LOG.info("Replacing "+regex+" with "+replacement+" in "+file);
        try {
            final String cur = FileUtils.readFileToString(file, "UTF-8");
            final String noStart = cur.replaceFirst(regex, replacement);
            FileUtils.writeStringToFile(file, noStart, "UTF-8");
        } catch (final IOException e) {
            LOG.warn("Could not replace string in file", e);
        }
    }

    public static void loadJarLibrary(final Class<?> jarRepresentative, 
        final String fileName) throws IOException {
        File tempDir = null;
        InputStream is = null; 
        try {
            tempDir = Files.createTempDir();
            final File tempLib = new File(tempDir, fileName); 
            is = jarRepresentative.getResourceAsStream("/" + fileName);
            FileUtils.copyInputStreamToFile(is, tempLib);
            System.load(tempLib.getAbsolutePath());
        } finally {
            FileUtils.deleteQuietly(tempDir);
            IOUtils.closeQuietly(is);
        }
    }
    
    public static String fileInJarToString(final String fileName) 
        throws IOException {
        InputStream is = null; 
        try {
            is = LanternUtils.class.getResourceAsStream("/" + fileName);
            return IOUtils.toString(is);
        } finally {
            IOUtils.closeQuietly(is);
        }
    }

    public static String jidToEmail(final String jid) {
        if (jid.contains("/")) {
            return StringUtils.substringBefore(jid, "/");
        }
        return jid;
    }

    public static boolean shouldProxy() {
        return LanternHub.settings().isGetMode() && 
            LanternHub.settings().isSystemProxy();
    }
    
    /*
    public static boolean shouldProxy(final HttpRequest request) {
        if (LanternHub.settings().isProxyAllSites()) {
            return true;
        }
        return LanternHub.whitelist().isWhitelisted(request);
    }
    */

    /**
     * Creates a typed object from the specified string. If the string is a
     * boolean, this returns a boolean, if an int, an int, etc.
     * 
     * @param val The string.
     * @return A typed object.
     */
    public static Object toTyped(final String val) {
        if (LanternUtils.isTrue(val)) {
            return true;
        } else if (LanternUtils.isFalse(val)) {
            return false;
        } else if (NumberUtils.isNumber(val)) {
            return Integer.parseInt(val);
        } 
        return val;
    }
    /**
     * Prints request headers.
     * 
     * @param request The request.
     */
    public static void printRequestHeaders(final HttpServletRequest request) {
        LOG.info(getRequestHeaders(request).toString());
    }
    
    /**
     * Gets request headers as a string.
     * 
     * @param request The request.
     * @return The request headers as a string.
     */
    public static String getRequestHeaders(final HttpServletRequest request) {
        final Enumeration<String> headers = request.getHeaderNames();
        final StringBuilder sb = new StringBuilder();
        sb.append("\n");
        sb.append(request.getRequestURL().toString());
        sb.append("\n");
        while (headers.hasMoreElements()) {
            final String headerName = headers.nextElement();
            sb.append(headerName);
            sb.append(": ");
            sb.append(request.getHeader(headerName));
            sb.append("\n");
        }
        return sb.toString();
    }
    
    
    /** 
     * returns bean property assocated with a method name of the form 
     * getXyzW -> xyzW or isXyzW -> xyzW
     *
     * returns null if no property name is deduced
     */
    public static String methodNameToProperty(final String methodName) {
        if (methodName.startsWith("get")) {
            return _lowerFirst(methodName.substring(3));
        }
        else if (methodName.startsWith("is")) {
            return _lowerFirst(methodName.substring(2));
        }
        else {
            return null;
        }
    }
    
    private static String _lowerFirst(final String s) {
        if (s == null) {
            return null;
        }
        if (s.length() > 1) {
            return s.substring(0,1).toLowerCase() + s.substring(1);
        }
        else {
            return s.toLowerCase();
        }
    }
    
    public static void zeroFill(char[] array) {
        if (array != null) {
            Arrays.fill(array, '\0');
        }
    }

    public static void zeroFill(byte[] array) {
        if (array != null) {
            Arrays.fill(array, (byte) 0);
        }
    }
    
    public static ConnectionConfiguration xmppConfig() {
        final ConnectionConfiguration config = 
            new ConnectionConfiguration("talk.google.com", 5222, "gmail.com");
        config.setExpiredCertificatesCheckEnabled(true);
        
        // We don't check for matching domains because Google Talk uses the
        // same cert for Google Apps domains, and this would always fail in
        // those cases.
        //config.setNotMatchingDomainCheckEnabled(true);
        config.setSendPresence(false);
        
        config.setCompressionEnabled(true);
        
        config.setRosterLoadedAtLogin(true);
        config.setReconnectionAllowed(false);
        config.setVerifyChainEnabled(true);
        config.setVerifyRootCAEnabled(true);
        config.setSelfSignedCertificateEnabled(false);
        final LanternTrustManager tm = 
            LanternHub.getKeyStoreManager().getTrustManager();
        config.setTruststorePath(tm.getTruststorePath());
        config.setTruststorePassword(tm.getTruststorePassword());
        
        final String[] cipherSuites = new String[] {
            //"TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA",
            //"TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA",
            //"TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA",
            //"TLS_DHE_DSS_WITH_CAMELLIA_256_CBC_SHA",
            //"TLS_DHE_RSA_WITH_AES_256_CBC_SHA",
            //"TLS_DHE_DSS_WITH_AES_256_CBC_SHA",
            "SSL_RSA_WITH_RC4_128_SHA",
            //"TLS_ECDH_RSA_WITH_AES_256_CBC_SHA",
            //"TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA",
            //"TLS_RSA_WITH_CAMELLIA_256_CBC_SHA",
            //"TLS_RSA_WITH_AES_256_CBC_SHA",
            //"TLS_ECDHE_ECDSA_WITH_RC4_128_SHA",
            //"TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA",
            //"TLS_ECDHE_RSA_WITH_RC4_128_SHA",
            //"TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA",
            //"TLS_DHE_RSA_WITH_CAMELLIA_128_CBC_SHA",
            //"TLS_DHE_DSS_WITH_CAMELLIA_128_CBC_SHA",
            //"TLS_DHE_DSS_WITH_RC4_128_SHA",
            //"TLS_DHE_RSA_WITH_AES_128_CBC_SHA",
            //"TLS_DHE_DSS_WITH_AES_128_CBC_SHA",
            //"TLS_ECDH_RSA_WITH_RC4_128_SHA",
            //"TLS_ECDH_RSA_WITH_AES_128_CBC_SHA",
            //"TLS_ECDH_ECDSA_WITH_RC4_128_SHA",
            //"TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA",
            //"TLS_RSA_WITH_SEED_CBC_SHA",
            //"TLS_RSA_WITH_CAMELLIA_128_CBC_SHA",
            //"TLS_RSA_WITH_RC4_128_MD5",
            //"TLS_RSA_WITH_RC4_128_SHA",
            //"TLS_RSA_WITH_AES_128_CBC_SHA",
            //"TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA",
            //"TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA",
            //"TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA",
            //"TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA",
            //"TLS_ECDH_RSA_WITH_3DES_EDE_CBC_SHA",
            //"TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA",
            //"SSL_RSA_FIPS_WITH_3DES_EDE_CBC_SHA",
            //"TLS_RSA_WITH_3DES_EDE_CBC_SHA",
        };
        config.setCipherSuites(cipherSuites);
        
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
    
    public static void configureXmpp() {
        XmppUtils.setGlobalConfig(xmppConfig());
    }
    
    public static SSLServerSocketFactory newTlsServerSocketFactory() {
        LOG.info("Creating TLS server socket factory");
        try {
            final LanternKeyStoreManager ksm = LanternHub.getKeyStoreManager();
            final KeyManagerFactory kmf = 
                loadKeyManagerFactory(ksm, getSslAlgorithm());
            
            // Initialize the SSLContext to work with our key managers.
            final SSLContext serverContext = SSLContext.getInstance("TLS");
            serverContext.init(kmf.getKeyManagers(), ksm.getTrustManagers(), null);
            return wrappedServerSocketFactory(serverContext.getServerSocketFactory());
        } catch (final NoSuchAlgorithmException e) {
            throw new Error("Could not create SSL server socket factory.", e);
        } catch (final KeyManagementException e) {
            throw new Error("Could not create SSL server socket factory.", e);
        }
    }

    private static String getSslAlgorithm() {
        String algorithm = 
            Security.getProperty("ssl.KeyManagerFactory.algorithm");
        if (algorithm == null) {
            algorithm = "SunX509";
        }
        return algorithm;
    }

    private static KeyManagerFactory loadKeyManagerFactory(
        final LanternKeyStoreManager ksm, final String algorithm) {
        try {
            final KeyStore ks = KeyStore.getInstance("JKS");
            ks.load(ksm.keyStoreAsInputStream(), ksm.getKeyStorePassword());
            
            // Set up key manager factory to use our key store
            final KeyManagerFactory kmf = KeyManagerFactory.getInstance(algorithm);
            kmf.init(ks, ksm.getCertificatePassword());
            return kmf;
        } catch (final KeyStoreException e) {
            throw new Error("Key manager issue", e);
        } catch (final UnrecoverableKeyException e) {
            throw new Error("Key manager issue", e);
        } catch (final NoSuchAlgorithmException e) {
            throw new Error("Key manager issue", e);
        } catch (final CertificateException e) {
            throw new Error("Key manager issue", e);
        } catch (final IOException e) {
            throw new Error("Key manager issue", e);
        }
    }

    private static SSLServerSocketFactory wrappedServerSocketFactory(
        final SSLServerSocketFactory ssf) {
        return new SSLServerSocketFactory() {
            @Override
            public ServerSocket createServerSocket() throws IOException {
                final SSLServerSocket ssl = 
                    (SSLServerSocket) ssf.createServerSocket();
                configure(ssl);
                return ssl;
            }
            @Override
            public ServerSocket createServerSocket(final int port, 
                final int backlog, final InetAddress ifAddress) 
                throws IOException {
                final SSLServerSocket ssl = 
                    (SSLServerSocket) ssf.createServerSocket(port, backlog, ifAddress);
                configure(ssl);
                return ssl;
            }
            @Override
            public ServerSocket createServerSocket(final int port, 
                final int backlog) throws IOException {
                final SSLServerSocket ssl = 
                    (SSLServerSocket) ssf.createServerSocket(port, backlog);
                configure(ssl);
                return ssl;
            }
            @Override
            public ServerSocket createServerSocket(final int port) 
                throws IOException {
                final SSLServerSocket ssl = 
                    (SSLServerSocket) ssf.createServerSocket(port);
                configure(ssl);
                return ssl;
            }
            @Override
            public String[] getDefaultCipherSuites() {
                return ssf.getDefaultCipherSuites();
            }
            @Override
            public String[] getSupportedCipherSuites() {
                return ssf.getSupportedCipherSuites();
            }
            
            private void configure(final SSLServerSocket ssl) {
                ssl.setNeedClientAuth(true);
                final String[] suites = IceConfig.getCipherSuites();
                if (suites != null && suites.length > 0) {
                    ssl.setEnabledCipherSuites(suites);
                }
            }
        };
    }


    public static SSLSocketFactory newTlsSocketFactory() {
        LOG.info("Creating TLS socket factory");
        try {
            final SSLContext clientContext = SSLContext.getInstance("TLS");
            final LanternKeyStoreManager ksm = LanternHub.getKeyStoreManager();
            final KeyManagerFactory kmf = 
                loadKeyManagerFactory(ksm, getSslAlgorithm());
            
            clientContext.init(kmf.getKeyManagers(), ksm.getTrustManagers(), null);
            return wrappedSocketFactory(clientContext.getSocketFactory());
        } catch (final NoSuchAlgorithmException e) {
            LOG.error("No TLS?", e);
            throw new Error("No TLS?", e);
        } catch (final KeyManagementException e) {
            LOG.error("Key managmement issue?", e);
            throw new Error("Key managmement issue?", e);
        }
    }

    private static SSLSocketFactory wrappedSocketFactory(final SSLSocketFactory sf) {
        return new SSLSocketFactory() {
            @Override
            public Socket createSocket() throws IOException {
                final SSLSocket sock = (SSLSocket) sf.createSocket();
                configure(sock);
                return sock;
            }
            
            @Override
            public Socket createSocket(final InetAddress address, 
                final int port, final InetAddress localAddress, 
                final int localPort) throws IOException {
                final SSLSocket sock = 
                    (SSLSocket) sf.createSocket(address, port, localAddress, localPort);
                configure(sock);
                return sock;
            }
            
            @Override
            public Socket createSocket(final String host, final int port, 
                final InetAddress localHost, final int localPort) 
                throws IOException, UnknownHostException {
                final SSLSocket sock = 
                    (SSLSocket) sf.createSocket(host, port, localHost, localPort);
                configure(sock);
                return sock;
            }
            
            @Override
            public Socket createSocket(final InetAddress host, 
                final int port) throws IOException {
                final SSLSocket sock = (SSLSocket) sf.createSocket(host, port);
                configure(sock);
                return sock;
            }
            
            @Override
            public Socket createSocket(final String host, final int port) 
                throws IOException, UnknownHostException {
                final SSLSocket sock = (SSLSocket) sf.createSocket(host, port);
                configure(sock);
                return sock;
            }
            
            @Override
            public Socket createSocket(final Socket s, final String host, 
                final int port, final boolean autoClose) throws IOException {
                final SSLSocket sock = 
                    (SSLSocket) sf.createSocket(s, host, port, autoClose);
                configure(sock);
                return sock;
            }

            @Override
            public String[] getDefaultCipherSuites() {
                return sf.getDefaultCipherSuites();
            }

            @Override
            public String[] getSupportedCipherSuites() {
                return sf.getSupportedCipherSuites();
            }
            
            private void configure(final SSLSocket sock) {
                sock.setNeedClientAuth(true);
                final String[] suites = IceConfig.getCipherSuites();
                if (suites != null && suites.length > 0) {
                    sock.setEnabledCipherSuites(suites);
                }
            }

        };
    }
    
    public static boolean isUnlimitedKeyStrength() {
        try {
            return Cipher.getMaxAllowedKeyLength("AES") == Integer.MAX_VALUE;
        } catch (final NoSuchAlgorithmException e) {
            LOG.error("No AES?", e);
            return false;
        }
    }

    public static String toEmail(final XMPPConnection conn) {
        final String jid = conn.getUser().trim();
        return XmppUtils.jidToUser(jid);
    }

    public static boolean isInClosedBeta(final String email) {
        final Set<String> in = LanternHub.settings().getInClosedBeta();
        return in.contains(email);
    }

    public static void addToClosedBeta(final String to) {
        final Set<String> in = LanternHub.settings().getInClosedBeta();
        in.add(to);
        LanternHub.settings().setInClosedBeta(in);
    }
}


