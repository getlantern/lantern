package org.lantern;

import io.netty.handler.codec.http.HttpHeaders;
import io.netty.handler.codec.http.HttpRequest;

import java.awt.Desktop;
import java.awt.Dimension;
import java.awt.Point;
import java.awt.Toolkit;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.Console;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOError;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.lang.reflect.InvocationTargetException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URLEncoder;
import java.net.UnknownHostException;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Enumeration;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.Scanner;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.zip.GZIPOutputStream;

import javax.crypto.Cipher;
import javax.net.ssl.SSLSocket;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.beanutils.PropertyUtils;
import org.apache.commons.codec.binary.Base64;
import org.apache.commons.httpclient.URIException;
import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOExceptionWithCause;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.SystemUtils;
import org.apache.commons.lang.math.NumberUtils;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.packet.Packet;
import org.lantern.event.Events;
import org.lantern.event.RefreshTokenEvent;
import org.lantern.proxy.pt.Flashlight;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;
import org.lantern.state.Settings;
import org.lantern.state.StaticSettings;
import org.lantern.util.PublicIpAddress;
import org.lantern.win.Registry;
import org.lastbamboo.common.offer.answer.NoAnswerException;
import org.lastbamboo.common.p2p.P2PClient;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.littleshoot.proxy.impl.ProxyUtils;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.ThreadUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.hash.HashCode;
import com.google.common.hash.Hashing;
import com.google.common.io.Files;

/**
 * Utility methods for use with Lantern.
 */
public class LanternUtils {


    private static final Logger LOG =
        LoggerFactory.getLogger(LanternUtils.class);
    
    private static final String REQUESTED_MODE_TOO_SOON =
            "Requesting mode before model populated! Testing?";

    private static final SecureRandom secureRandom = new SecureRandom();

    private static boolean amFallbackProxy = false;

    private static String keystorePath = "<UNSET>";

    private static Model model;

    private static final Properties privateProps = new Properties();
    private static final File privatePropsFile;

    public static boolean isDevMode() {
        return LanternClientConstants.isDevMode();
    }

    /*
    public static Socket openRawOutgoingPeerSocket(
        final URI uri, final P2PClient p2pClient,
        final Map<URI, AtomicInteger> peerFailureCount) throws IOException {
        return openOutgoingPeerSocket(uri, p2pClient, peerFailureCount, true);
    }
    */

    static {
        LOG.debug("LOADING PRIVATE PROPS FILE!");
        // The following are only used for diagnostics.
        if (LanternClientConstants.TEST_PROPS.isFile()) {
            privatePropsFile = LanternClientConstants.TEST_PROPS;
        } else if (LanternClientConstants.TEST_PROPS2.isFile()){
            privatePropsFile = LanternClientConstants.TEST_PROPS2;
        } else {
            privatePropsFile = new File("test.properties");
        }
        if (privatePropsFile.isFile()) {
            InputStream is = null;
            try {
                is = new FileInputStream(privatePropsFile);
                privateProps.load(is);
                LOG.debug("LOADED PRIVATE PROPS FILE!");
            } catch (final IOException e) {
                LOG.debug("COULD NOT LOAD PRIVATE PROPS FILE AT "+ 
                        privatePropsFile);
            } finally {
                IOUtils.closeQuietly(is);
            }
        } else {
            LOG.debug("NO PRIVATE PROPS FILE AT: "+privatePropsFile);
        }
    }

    public static FiveTuple openOutgoingPeer(
        final URI uri, final P2PClient<FiveTuple> p2pClient,
        final Map<URI, AtomicInteger> peerFailureCount) throws IOException {

        if (p2pClient == null) {
            LOG.info("P2P client is null. Testing?");
            throw new IOException("P2P client not connected");
        }

        // Start the connection attempt.
        try {
            LOG.debug("Creating a new socket to {}", uri);
            return p2pClient.newSocket(uri);

        } catch (final NoAnswerException nae) {
            // This is tricky, as it can mean two things. First, it can mean
            // the XMPP message was somehow lost. Second, it can also mean
            // the other side is actually not there and didn't respond as a
            // result.
            LOG.info("Did not get answer!! Closing channel from browser", nae);
            final AtomicInteger count = peerFailureCount.get(uri);
            if (count == null) {
                LOG.debug("Incrementing failure count");
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
            LOG.debug("Could not connect to peer", ioe);
            throw ioe;
        }
    }

    public static Socket openOutgoingPeerSocket(final URI uri,
        final P2PClient<Socket> p2pClient,
        final Map<URI, AtomicInteger> peerFailureCount) throws IOException {
        return openOutgoingPeerSocket(uri, p2pClient, peerFailureCount, false);
    }

    private static Socket openOutgoingPeerSocket(
        final URI uri, final P2PClient<Socket> p2pClient,
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
                    Arrays.asList(((SSLSocket)sock).getEnabledCipherSuites()));
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
            LOG.info("Could not connect to peer", ioe);
            throw ioe;
        }
    }

    public static byte[] utf8Bytes(final String str) {
        try {
            return str.getBytes("UTF-8");
        } catch (final UnsupportedEncodingException e) {
            LOG.error("No UTF-8?", e);
            throw new RuntimeException("No UTF-8?", e);
        }
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
        LOG.debug("Checking for network connection by looking up public IP");
        final InetAddress ip =
            new PublicIpAddress().getPublicIpAddress();

        LOG.debug("Returning result: "+ip);
        return ip != null;
    }

    public static int randomPort() {
        if (LanternConstants.ON_APP_ENGINE) {
            // Can't create server sockets on app engine.
            return -1;
        }
        for (int i = 0; i < 20; i++) {
            int randomInt = secureRandom.nextInt();
            if (randomInt == Integer.MIN_VALUE) {
                // Math.abs(Integer.MIN_VALUE) == Integer.MIN_VALUE -- caught
                // by FindBugs.
                randomInt = 0;
            }
            final int randomPort = 1024 + (Math.abs(randomInt) % 60000);
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
            int randomInt = secureRandom.nextInt();
            if (randomInt == Integer.MIN_VALUE) {
                // see above
                randomInt = 0;
            }
            return 1024 + (Math.abs(randomInt) % 60000);
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
     *
     * @throws IOException If the executable cannot be found.
     */
    public static String runKeytool(final String... args) {

        final Collection<String> withMx = new ArrayList<String>();
        withMx.addAll(Arrays.asList(args));
        withMx.add("-JXms64m");
        try {
            final CommandLine command = new CommandLine(findKeytoolPath(), args);
            command.execute();
            final String output = command.getStdOut();
            if (!command.isSuccessful()) {
                LOG.info("Command failed!! Args: {}\nResult: {}", 
                        Arrays.asList(args), output);
            }
            return output;
        } catch (IOException e) {
            LOG.warn("Could not run key tool?", e);
        }
        return "";
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

    public static boolean isLanternHub(final String jabberid) {
        try {
            final String userid = LanternXmppUtils.jidToEmail(jabberid);
            return LanternClientConstants.LANTERN_JID.equals(userid);
        } catch (EmailAddressUtils.NormalizationException e) {
            LOG.warn("Unnormalizable jabberid: " + jabberid);
            // Since the controller's id is normalizable, this must be
            // something else.
            return false;
        }
    }

    public static Packet activateOtr(final XMPPConnection conn) {
        return XmppUtils.goOffTheRecord(LanternClientConstants.LANTERN_JID,
                                        conn);
    }

    public static Packet deactivateOtr(final XMPPConnection conn) {
        return XmppUtils.goOnTheRecord(LanternClientConstants.LANTERN_JID,
                                       conn);
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
            LOG.debug("No console -- using System.in...");
            final Scanner sc = new Scanner(System.in, "UTF-8");
            final char[] line = sc.nextLine().toCharArray();
            sc.close();
            return line;
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
        LOG.debug("No console -- using System.in...");
        final Scanner sc = new Scanner(System.in, "UTF-8");
        //sc.useDelimiter("\n");
        //return sc.next();
        final String line = sc.nextLine();
        sc.close();
        return line;
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
        LOG.debug("Replacing "+regex+" with "+replacement+" in "+file);
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
            if (is == null) {
                final String msg = "No file in jar named: "+fileName;
                LOG.warn(msg);
                throw new IOException(msg);
            }
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

    public static boolean isAnonymizedGoogleTalkAddress(final String email) {
        final boolean isEmail = !email.contains(".talk.google.com");
        /*
        if (isEmail) {
            LOG.debug("Allowing email {}", email);
        } else {
            LOG.debug("Is a JID {}", email);
        }
        */
        return isEmail;
    }

    public static Point getScreenCenter(final int width, final int height) {
        final Toolkit toolkit = Toolkit.getDefaultToolkit();
        final Dimension screenSize = toolkit.getScreenSize();
        final int x = (screenSize.width - width) / 2;
        final int y = (screenSize.height - height) / 2;
        return new Point(x, y);
    }


    public static boolean waitForServer(final int port) {
        return waitForServer(port, 60 * 1000);
    }

    public static boolean waitForServer(final int port, final int millis) {
        return waitForServer("127.0.0.1", port, millis);
    }
    
    public static boolean waitForServer(final String host, final int port, final int millis) {
        return waitForServer(new InetSocketAddress(host, port), millis);
    }
    
    public static boolean waitForServer(InetSocketAddress address, int millis) {
        final long start = System.currentTimeMillis();
        while (System.currentTimeMillis() - start < millis) {
            final Socket sock = new Socket();
            try {
                sock.connect(address, 2000);
                sock.close();
                return true;
            } catch (final IOException e) {
            }
            try {
                Thread.sleep(20);
            } catch (final InterruptedException e) {
                LOG.info("Interrupted?");
            }
        }
        LOG.error("Never able to connect with local server on port {}! " +
            "Maybe couldn't bind? "+ThreadUtils.dumpStack(), address.getPort());
        return false;
    }

    /**
     * Determines whether or not oauth data should be persisted to disk. It is
     * only persisted if we can do so safely and securely but also cleanly.
     *
     * Fixme: this should actually be a user preference refs #586
     *
     * @return <code>true</code> if credentials should be persisted to disk,
     * otherwise <code>false</code>.
     */
    public static boolean persistCredentials() {
        return true;
    }


    /**
     * Accesses the object to set a property on with a trivial json-pointer
     * syntax as in /object1/object2.
     *
     * Public for testing. Note this is actually not use in favor of
     * ModelMutables that consolidates all accessible methods.
     */
    public static Object getTargetForPath(final Object root, final String path)
        throws IllegalAccessException, InvocationTargetException,
        NoSuchMethodException {
        if (!path.contains("/")) {
            return root;
        }
        final String curProp = StringUtils.substringBefore(path, "/");
        final Object propObject;
        if (curProp.isEmpty()) {
            propObject = root;
        } else {
            propObject = PropertyUtils.getProperty(root, curProp);
        }
        final String nextProp = StringUtils.substringAfter(path, "/");
        if (nextProp.contains("/")) {
            return getTargetForPath(propObject, nextProp);
        }
        return propObject;
    }

    public static void setFromPath(final Object root, final String path, final Object value)
            throws IllegalAccessException, InvocationTargetException,
            NoSuchMethodException {
            if (!path.contains("/")) {
                PropertyUtils.setProperty(root, path, value);
                return;
            }
            final String curProp = StringUtils.substringBefore(path, "/");
            final Object propObject;
            if (curProp.isEmpty()) {
                propObject = root;
            } else {
                propObject = PropertyUtils.getProperty(root, curProp);
            }
            final String nextProp = StringUtils.substringAfter(path, "/");
            if (nextProp.contains("/")) {
                setFromPath(propObject, nextProp, value);
                return;
            }
            PropertyUtils.setProperty(propObject, nextProp, value);
        }

    public static boolean isLocalHost(final Socket sock) {
        return isLocalHost((InetSocketAddress) sock.getRemoteSocketAddress());
    }
    
    public static boolean isLocalHost(final InetSocketAddress address) {
        return address.getAddress().isLoopbackAddress();
    }

    /**
     * Returns whether or not the string is either true of false. If it's some
     * other random string, this returns false.
     *
     * @param str The string to test.
     * @return <code>true</code> if the string is either true or false
     * (or on or off), otherwise false.
     */
    public static boolean isTrueOrFalse(final String str) {
        if (LanternUtils.isTrue(str)) {
            return true;
        } else if (LanternUtils.isFalse(str)) {
            return true;
        }
        return false;
    }

    /**
     * The completion of the native calls is dependent on OS process
     * scheduling, so we need to wait until files actually exist.
     *
     * @param file The file to wait for.
     */
    public static void waitForFile(final File file) {
        int i = 0;
        while (!file.isFile() && i < 100) {
            try {
                Thread.sleep(80);
                i++;
            } catch (final InterruptedException e) {
                LOG.error("Interrupted?", e);
            }
        }
        if (!file.isFile()) {
            LOG.error("Still could not create file at: {}", file);
        } else {
            LOG.info("Successfully created file at: {}", file);
        }
    }


    public static void fullDelete(final File file) {
        file.deleteOnExit();
        if (file.isFile() && !file.delete()) {
            LOG.error("Could not delete file {}!!", file);
        }
    }

    public static InetSocketAddress isa(final String host, final int port) {
        final InetAddress ia;
        try {
            ia = InetAddress.getByName(host);
        } catch (final UnknownHostException e) {
            LOG.error("Could not lookup host address at "+host, e);
            throw new Error("Bad host", e);
        }
        return new InetSocketAddress(ia, port);
    }

    public static URI newURI(final String userId) {
        try {
            return new URI(userId);
        } catch (URISyntaxException e) {
            LOG.error("Could not create URI from "+userId);
            throw new Error("Bad URI: "+userId);
        }
    }


    /**
     * We call this dynamically instead of using a constant because the API
     * PORT is set at startup, and we don't want to create a race condition
     * for retrieving it.
     *
     * @return The base URL for photos.
     */
    public static String photoUrlBase() {
        return StaticSettings.getLocalEndpoint()+"/photo/";
    }

    public static String defaultPhotoUrl() {
        return LanternUtils.photoUrlBase() + "?email=default";
    }

    public static boolean fileContains(final File file, final String str) {
        InputStream fis = null;
        try {
            fis = new FileInputStream(file);
            final String text = IOUtils.toString(fis);
            return text.contains(str);
        } catch (final IOException e) {
            LOG.warn("Could not read file?", e);
        } finally {
            IOUtils.closeQuietly(fis);
        }
        return false;
    }

    /**
     * Modifies .desktop files on Ubuntu with out hack to set our icon.
     *
     * @param path The path to the file.
     */
    public static void addStartupWMClass(final String path) {
        final File desktopFile = new File(path);
        if (!desktopFile.isFile()) {
            LOG.warn("No lantern desktop file at: {}", desktopFile);
            return;
        }
        final Collection<?> lines =
            Arrays.asList("StartupWMClass=127.0.0.1__"+

            // We use the substring here to get rid of the leading "/"
            StaticSettings.getPrefix().substring(1)+"_index.html");
        try {
            FileUtils.writeLines(desktopFile, "UTF-8", lines, true);
        } catch (final IOException e) {
            LOG.warn("Error writing to: "+desktopFile, e);
        }
    }

    public static String photoUrl(final String email) {
        try {
            return LanternUtils.photoUrlBase() + "?email=" +
                    URLEncoder.encode(email, "UTF-8");
        } catch (final UnsupportedEncodingException e) {
            LOG.error("Unsupported encoding?", e);
            throw new RuntimeException(e);
        }
    }

    public static String runCommand(final String cmd, final String... args)
            throws IOException {
        LOG.debug("Command: {}\nargs: {}", cmd, Arrays.asList(args));
        final CommandLine command;
        if (SystemUtils.IS_OS_WINDOWS) {
            String[] cmdline = new String[args.length + 3];
            cmdline[0] = "cmd.exe";
            cmdline[1] = "/C";
            cmdline[2] = cmd;
            for (int i=0; i<args.length; ++i) {
                cmdline[3+i] = args[i];
            }
            command = new CommandLine(cmdline);
        } else {
            command = new CommandLine(cmd, args);
        }
        command.execute();
        final String output = command.getStdOut();
        if (!command.isSuccessful()) {
            final String msg = "Command failed!! Args: " + Arrays.asList(args)
                    + " Result: " + output;
            LOG.error(msg);
            throw new IOException(msg);
        }
        return output;
    }

    public static void addCSPHeader(HttpServletResponse resp) {
        // see http://cspisawesome.com/ for a CSP header generator
        String[] paths = {"ws://127.0.0.1",
                "http://127.0.0.1",
                "ws://localhost",
                "http://localhost"
                };

        List<String> policies = new ArrayList<String>();
        for (String path : paths) {
            policies.add(path + ":" + StaticSettings.getApiPort());
        }
        policies.add("http://" + Flashlight.STATS_ADDR);
        String localhost = StringUtils.join(policies, " ");
        resp.addHeader("Content-Security-Policy",
            "default-src " + localhost + " 'unsafe-inline' 'unsafe-eval'; " +
            "img-src data:// https://www.google-analytics.com " + localhost);
    }

    /**
     * Returns whether or not this Lantern is running as a fallback proxy.
     *
     * @return <code>true</code> if it's a fallback proxy, otherwise
     * <code>false</code>.
     */
    public static boolean isFallbackProxy() {
        return amFallbackProxy;
    }

    public static void setFallbackProxy(final boolean fallbackProxy) {
        // To check whether this is set in time for it to be picked up.
        LOG.info("I am a fallback proxy");
        amFallbackProxy = fallbackProxy;
    }

    public static String getFallbackKeystorePath() {
        return keystorePath;
    }

    public static void setFallbackKeystorePath(final String path) {
        LOG.info("Setting keystorePath to '" + path + "'");
        keystorePath = path;
    }

    public static boolean isTesting() {
        final String prop = System.getProperty("testing");
        return "true".equalsIgnoreCase(prop);
    }

    public static byte[] compress(final String str) {
        if (StringUtils.isBlank(str)) {
            throw new IllegalArgumentException("can compress empty string!");
        }
        final ByteArrayOutputStream baos = new ByteArrayOutputStream();
        GZIPOutputStream gzip = null;
        try {
            gzip = new GZIPOutputStream(baos);
            gzip.write(str.getBytes("UTF-8"));
            gzip.close();
            return baos.toByteArray();
        } catch (final IOException e) {
            LOG.error("Could not write to byte array?", e);
            throw new Error("Could not write to byte array?", e);
        } finally {
            IOUtils.closeQuietly(gzip);
        }
    }

    /**
     * Sets the model -- this should be called very early in the overall 
     * initialization sequence.
     * 
     * @param model The model for application-wide settings.
     */
    public static void setModel(final Model model) {
        LanternUtils.model = model;
        
        // If we're testing on CI, use the pro-configured refresh token.
        if (SystemUtils.IS_OS_LINUX && privatePropsFile != null && privatePropsFile.isFile()) {
            final Settings set = model.getSettings();
            final String existing = set.getRefreshToken();
            if (StringUtils.isNotBlank(existing)) {
                final String rt = privateProps.getProperty("refresh_token");
                set.setRefreshToken(rt);
            }
        }
    }
    
    public static Model getModel() {
        if (model == null) {
            LOG.error("No model yet? Testing?");
        }
        return model;
    }

    public static boolean isGet() {
        if (model == null) {
            LOG.error(REQUESTED_MODE_TOO_SOON);
            return true;
        }
        return model.getSettings().getMode() == Mode.get;
    }
    
    public static boolean isGive() {
        if (model == null) {
            LOG.error(REQUESTED_MODE_TOO_SOON);
            return false;
        }
        return model.getSettings().getMode() == Mode.give;
    }
    
    public static Certificate certFromBase64(String base64Cert)
            throws CertificateException {
        return certFromBytes(Base64.decodeBase64(base64Cert));
    }

    public static Certificate certFromBytes(byte[] bytes)
            throws CertificateException {
        final InputStream is = new ByteArrayInputStream(bytes);

        try {
            final CertificateFactory cf = CertificateFactory
                    .getInstance("X.509");
            return cf.generateCertificate(is);
        } finally {
            IOUtils.closeQuietly(is);
        }
    }
    
    /**
     * Cargo culted from org.eclipse.jdt.launching.SocketUtil.
     * 
     * @return
     */
    public static int findFreePort() {
        ServerSocket socket = null;
        try {
            socket = new ServerSocket(0);
            return socket.getLocalPort();
        } catch (IOException e) {
        } finally {
            if (socket != null) {
                try {
                    socket.close();
                } catch (IOException e) {
                }
            }
        }
        return -1;
    }
    
    /**
     * Finds a free port, returning the specified port if it's available.
     * 
     * @param suggestedPort The preferred port to use.
     * @return A free port, which may or may not be the preferred port.
     */
    public static int findFreePort(final int suggestedPort) {
        ServerSocket socket = null;
        try {
            socket = new ServerSocket(suggestedPort);
            return socket.getLocalPort();
        } catch (IOException e) {
            return findFreePort();
        } finally {
            IOUtils.closeQuietly(socket);
        }
    }

    public static String[] hostAndPortFrom(HttpRequest httpRequest) {
        String hostAndPort = ProxyUtils.parseHostAndPort(httpRequest);
        if (StringUtils.isBlank(hostAndPort)) {
            List<String> hosts = httpRequest.headers().getAll(
                    HttpHeaders.Names.HOST);
            if (hosts != null && !hosts.isEmpty()) {
                hostAndPort = hosts.get(0);
            }
        }
        String[] result = new String[2];
        String[] parsed = hostAndPort.split(":");
        result[0] = parsed[0];
        result[1] = parsed.length == 2 ? parsed[1] : null;
        return result;
    }

    /**
     * Method for finding an OS-specific file with the given name that will
     * reside in a different location in installed versions that it will in
     * dev versions.
     * 
     * @param fileName The name of the file.
     * @return The correct file instance, normalizing across installed and
     * uninstalled versions and operating systems.
     */
    public static File osSpecificExecutable(final String fileName) {
        final File installed;
        if (SystemUtils.IS_OS_WINDOWS) {
            installed = new File(fileName+".exe");
        } else {
            installed = new File(fileName);
        }
        if (installed.isFile()) {
            return installed;
        }
        if (SystemUtils.IS_OS_MAC_OSX) {
            return new File("./install/osx", fileName);
        }

        if (SystemUtils.IS_OS_WINDOWS) {
            return new File("./install/win", fileName);
        }

        if (SystemUtils.OS_ARCH.contains("64")) {
            return new File("./install/linux_x86_64", fileName);
        }
        return new File("./install/linux_x86_32", fileName);
    }
    
    /**
     * Checks if FireFox is the user's default browser on Windows. As of this
     * writing, this is only tested on Windows 8.1 but should theoretically
     * work on other Windows versions as well.
     * 
     * @return <code>true</code> if Firefox is the user's default browser,
     * otherwise <code>false</code>.
     */
    public static boolean firefoxIsDefaultBrowser() {
        if (!SystemUtils.IS_OS_WINDOWS) {
            return false;
        }
        final String key = "Software\\Microsoft\\Windows\\Shell\\Associations"
                + "\\UrlAssociations\\http\\UserChoice";
        final String name = "ProgId";
        final String result = Registry.read(key, name);
        if (StringUtils.isBlank(result)) {
            LOG.error("Could not find browser registry entry on: {}, {}", 
                SystemUtils.OS_NAME, SystemUtils.OS_VERSION);
            return false;
        }
        return result.toLowerCase().contains("firefox");
    }

    /**
     * Sets oauth tokens. WARNING: This is not thread safe. Callers should
     * ensure they will not call this method from different threads
     * simultaneously.
     * 
     * @param set The settings
     * @param refreshToken The refresh token
     * @param accessToken The access token
     * @param expiresInSeconds The number of seconds the access token expires in
     * @param modelIo The class for storing the tokens.
     */
    public static void setOauth(final Settings set, final String refreshToken,
            final String accessToken, final long expiresInSeconds,
            final ModelIo modelIo) {
        if (StringUtils.isBlank(accessToken)) {
            LOG.warn("Null access {} token -- not logging in!", accessToken);
            return;
        }
        set.setAccessToken(accessToken);
        
        // Set our expiry time 30 seconds before the actual expiry time to
        // make sure we never cut this too close (for example checking the 
        // expiry time and then making a request that itself takes 30 seconds
        // to connect).
        set.setExpiryTime(System.currentTimeMillis() + 
                ((expiresInSeconds-30) * 1000));
        set.setUseGoogleOAuth2(true);
        
        // Only set the refresh token if it's not null. OAuth endpoints will
        // often return blank refresh tokens if they expect you to just keep
        // using the same one.
        if (StringUtils.isNotBlank(refreshToken)) {
            set.setRefreshToken(refreshToken);
            Events.asyncEventBus().post(new RefreshTokenEvent(refreshToken));
        }
        // Could be null for testing.
        if (modelIo != null) {
            modelIo.write();
        }
    }
    
    /**
     * Extracts a file from the current classloader/jar executable to a
     * specified directory.
     * 
     * @param path The path of the file in the jar
     * @param dir The desired directory to extract to.
     * @return The path to the extracted file copied to the file system.
     * @throws IOException If there's an error finding or copying the file.
     */
    public static File extractExecutableFromJar(final String path,
            final File dir) throws IOException {
        final File tmpFile = extractFileFromJar(path);
        File destFile = new File(dir, tmpFile.getName());

        if (destFile.exists() && isSame(destFile, tmpFile)) {
            LOG.info("File {} is unchanged, leaving alone",
                    destFile.getAbsolutePath());
            tmpFile.delete();
            return destFile;
        } else {
            if (!destFile.exists()) {
                File targetDir = destFile.getParentFile();
                LOG.info("Making target directory {}",
                        targetDir.getAbsolutePath());
                if (!targetDir.exists() && !targetDir.mkdirs()) {
                    String msg = "Could not make target directory "
                            + targetDir.getAbsolutePath();
                    LOG.error(msg);
                    throw new IOException(msg);
                }
            } else {
                // We need to delete the old file before trying to move the new
                // file in place over it.
                // See https://docs.oracle.com/javase/7/docs/api/java/io/File.html#renameTo(java.io.File)
                LOG.info("File {} is out of date, deleting",
                        destFile.getAbsolutePath());
                if (!destFile.delete()) {
                    LOG.warn("Could not delete old file at {}", destFile);
                }
            }
            
            LOG.info("Moving {} to {}", tmpFile.getAbsolutePath(), destFile.getAbsolutePath());
            try {
                FileUtils.moveFile(tmpFile, destFile);
            } catch (Exception e) {
                String msg = String.format(
                        "Unable to move file to destination %1$s: %2$s",
                        destFile.getAbsolutePath(), e.getMessage());
                LOG.error(msg);
                throw new IOException(msg);
            }            
        }
        
        if (!destFile.setExecutable(true)) {
            final String msg = "Could not make file executable at "
                    + destFile.getAbsolutePath();
            LOG.error(msg);
            throw new IOException(msg);
        }
        
        return destFile;
    }
    
    public static boolean isSame(File a, File b) throws IOException {
        HashCode hashA = Files.hash(b, Hashing.sha256());
        HashCode hashB = Files.hash(a, Hashing.sha256());
        return hashA.equals(hashB);
    }
    
    /**
     * Extracts a file from the current classloader/jar file to a temporary
     * directory.
     * 
     * @param path The path of the file in the jar
     * @return The path to the extracted file copied to the file system.
     * @throws IOException If there's an error finding or copying the file.
     */
    public static File extractFileFromJar(final String path) throws IOException {
        final File dir = Files.createTempDir();
        return extractFileFromJar(path, dir);
    }
    
    /**
     * Extracts a file from the current classloader/jar file to the specified
     * directory.
     * 
     * @param path The path of the file in the jar.
     * @param dir The directory to extract to.
     * @return The path to the extracted file copied to the file system.
     * @throws IOException If there's an error finding or copying the file.
     */
    public static File extractFileFromJar(final String path, final File dir) 
            throws IOException {
        if (!dir.isDirectory() && !dir.mkdirs()) {
            throw new IOException("Could not make temp dir at: "+path);
        }
        final String name = StringUtils.substringAfterLast(path, "/");
        if (StringUtils.isBlank(name)) {
            throw new IllegalArgumentException("Bad path: "+path);
        }
        final File temp = new File(dir, name);
        if (temp.isFile()) {
            if (!temp.delete()) {
                LOG.error("Could not delete existing file at path {}", temp);
            }
        }
        
        InputStream is = null;
        OutputStream os  = null;
        try {
            is = ClassLoader.getSystemResourceAsStream(path);
            if (is == null) {
                throw new IOException("No input at "+path);
            }
            os = new FileOutputStream(temp);
            IOUtils.copy(is, os);
        } finally {
            IOUtils.closeQuietly(is);
            IOUtils.closeQuietly(os);
        }
        return temp;
    }
}
