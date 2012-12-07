package org.lantern;

import java.awt.Desktop;
import java.awt.Dimension;
import java.awt.Point;
import java.awt.Toolkit;
import java.io.Console;
import java.io.File;
import java.io.IOError;
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
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Collection;
import java.util.Enumeration;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Queue;
import java.util.Scanner;
import java.util.concurrent.atomic.AtomicInteger;

import javax.crypto.Cipher;
import javax.net.ssl.SSLSocket;
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
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.jboss.netty.handler.codec.http.HttpMessage;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.packet.Packet;
import org.jivesoftware.smack.packet.Presence;
import org.lantern.state.Model;
import org.lastbamboo.common.offer.answer.NoAnswerException;
import org.lastbamboo.common.p2p.P2PClient;
import org.lastbamboo.common.stun.client.PublicIpAddress;
import org.littleshoot.commom.xmpp.XmppUtils;
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
    
    /*
    public static Socket openRawOutgoingPeerSocket(
        final URI uri, final P2PClient p2pClient,
        final Map<URI, AtomicInteger> peerFailureCount) throws IOException {
        return openOutgoingPeerSocket(uri, p2pClient, peerFailureCount, true);
    }
    */
    
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
                LOG.warn("Not an SSL socket...");
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
        final InetAddress ip = 
            new PublicIpAddress().getPublicIpAddress();
        return ip != null;
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
            return readLineCliNoConsole();
        }
        try {
            return console.readLine();
        } catch (final IOError e) {
            throw new IOException("Could not read line from console", e);
        }
    }
        
    public static String readLineCliNoConsole() {
        LOG.info("No console -- using System.in...");
        final Scanner sc = new Scanner(System.in, "UTF-8");
        //sc.useDelimiter("\n");
        //return sc.next();
        return sc.nextLine();
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
        final ObjectWriter writer = mapper.writerWithView(view);
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

    public static boolean isNotJid(final String email) {
        final boolean isEmail = !email.contains(".talk.google.com");
        if (isEmail) {
            LOG.debug("Allowing email {}", email);
        } else {
            LOG.debug("Is a JID {}", email);
        }
        return isEmail;
    }
    
    public static boolean isGoogleTalkReachable() {
        final Socket sock = new Socket();
        try {
            sock.connect(new InetSocketAddress("talk.google.com", 5222), 40000);
            return true;
        } catch (final IOException e) {
            return false;
        }
    }
    
    public static Point getScreenCenter(final int width, final int height) {
        final Toolkit toolkit = Toolkit.getDefaultToolkit();
        final Dimension screenSize = toolkit.getScreenSize();
        final int x = (screenSize.width - width) / 2;
        final int y = (screenSize.height - height) / 2;
        return new Point(x, y);
    }

    public static void waitForServer(final int port) {
        int attempts = 0;
        while (attempts < 10000) {
            final Socket sock = new Socket();
            try {
                final SocketAddress isa = 
                    new InetSocketAddress("127.0.0.1", port);
                sock.connect(isa, 2000);
                return;
            } catch (final IOException e) {
            }
            try {
                Thread.sleep(100);
            } catch (final InterruptedException e) {
                LOG.info("Interrupted?");
            }
            attempts++;
        }
        LOG.error("Never able to connect with local server! " +
            "Maybe couldn't bind?");
    }

    public static boolean isLanternMessage(final Presence pres) {
        final Object prop = pres.getProperty(XmppMessageConstants.PROFILE);
        return prop != null;
    }

    public static String getLocalEndpoint(final Model model) {
        return model.getConnectivity().getLocalEndpoint();
    }

}


