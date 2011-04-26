package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.Socket;
import java.net.SocketException;
import java.net.URI;
import java.net.UnknownHostException;
import java.util.Collection;
import java.util.Enumeration;
import java.util.List;
import java.util.Map;
import java.util.Queue;
import java.util.Random;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.zip.GZIPInputStream;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
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
import org.lastbamboo.common.offer.answer.NoAnswerException;
import org.lastbamboo.common.p2p.P2PClient;
import org.lastbamboo.common.stun.client.PublicIpAddress;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.collect.Sets;
import com.maxmind.geoip.Country;
import com.maxmind.geoip.LookupService;

/**
 * Utility methods for use with Lantern.
 */
public class LanternUtils {

    private static final Logger LOG = 
        LoggerFactory.getLogger(LanternUtils.class);
    
    private static String MAC_ADDRESS;
    
    private static final File CONFIG_DIR = 
        new File(System.getProperty("user.home"), ".lantern");
    
    public static final ClientSocketChannelFactory clientSocketChannelFactory =
        new NioClientSocketChannelFactory(
            Executors.newCachedThreadPool(),
            Executors.newCachedThreadPool());
    
    /**
     * Censored country codes, in order of population.
     */
    private static final Collection<String> CENSORED =
        Sets.newHashSet(
            "CN",
            "IN",
            "PK",
            "RU",
            "VN",
            "EG",
            "ET",
            "IR",
            "TH",
            "MM",
            "KR",
            "UA",
            "SD",
            "DZ",
            "MA",
            "AF",
            "UZ",
            "SA",
            "YE",
            "SY",
            "KZ",
            "TN",
            "BY",
            "AZ",
            "LY",
            "OM");
        //Sets.newHashSet("China", "Iran", "Burma", "Vietnam", "Egypt", 
        //    "Bahrain", "Tunisia", "Syria", "Libya", "Venezuela");
        
    // These country codes have US export restrictions, and therefore cannot
    // access App Engine sites.
    private static final Collection<String> EXPORT_RESTRICTED =
        Sets.newHashSet(
            "SY");
    
    private static final File UNZIPPED = new File("GeoIP.dat");
    
    private static LookupService lookupService;
    
    static {
        if (!UNZIPPED.isFile())  {
            final File file = new File("GeoIP.dat.gz");
            GZIPInputStream is = null;
            OutputStream os = null;
            try {
                is = new GZIPInputStream(new FileInputStream(file));
                os = new FileOutputStream(UNZIPPED);
                IOUtils.copy(is, os);
            } catch (final IOException e) {
                LOG.warn("Error expanding file?", e);
            } finally {
                IOUtils.closeQuietly(is);
                IOUtils.closeQuietly(os);
            }
        }
        try {
            lookupService = new LookupService(UNZIPPED, 
                    LookupService.GEOIP_MEMORY_CACHE);
        } catch (final IOException e) {
            lookupService = null;
        }
    }
    
    public static boolean isCensored() {
        return isCensored(PublicIpAddress.getPublicIpAddress());
    }
    
    public static boolean isCensored(final InetAddress address) {
        return isMatch(address, CENSORED);
    }

    public static boolean isCensored(final String address) throws IOException {
        return isCensored(InetAddress.getByName(address));
    }
    
    public static boolean isExportRestricted() {
        return isExportRestricted(PublicIpAddress.getPublicIpAddress());
    }
    
    public static boolean isExportRestricted(final InetAddress address) { 
        return isMatch(address, EXPORT_RESTRICTED);
    }

    public static boolean isExportRestricted(final String address) 
        throws IOException {
        return isExportRestricted(InetAddress.getByName(address));
    }
    
    public static boolean isMatch(final InetAddress address, 
        final Collection<String> countries) { 
        final Country country = lookupService.getCountry(address);
        LOG.info("Country is: {}", country);
        return countries.contains(country.getCode().trim());
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
                
                public void operationComplete(final ChannelFuture cf) 
                    throws Exception {
                    if (cf.isSuccess()) {
                        ch.write(message);
                    }
                }
            });
        }
    }

    public static Socket openOutgoingPeerSocket(
        final Channel browserToProxyChannel,
        final URI uri, final ChannelHandlerContext ctx,
        final ProxyStatusListener proxyStatusListener,
        final P2PClient p2pClient,
        final Map<URI, AtomicInteger> peerFailureCount) throws IOException {
        
        // This ensures we won't read any messages before we've successfully
        // created the socket.
        browserToProxyChannel.setReadable(false);

        // Start the connection attempt.
        try {
            LOG.info("Creating a new socket to {}", uri);
            final Socket sock = p2pClient.newSocket(uri);
            browserToProxyChannel.setReadable(true);
            startReading(sock, browserToProxyChannel);
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
                proxyStatusListener.onCouldNotConnectToPeer(uri);
            } 
            throw nae;
        } catch (final IOException ioe) {
            proxyStatusListener.onCouldNotConnectToPeer(uri);
            LOG.warn("Could not connect to peer", ioe);
            throw ioe;
        }
    }
    
    private static void startReading(final Socket sock, final Channel channel) {
        final Runnable runner = new Runnable() {

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
                        count += n;
                        LOG.info("In while");
                    }
                    LOG.info("Out of while");
                    LanternUtils.closeOnFlush(channel);

                } catch (final IOException e) {
                    LOG.info("Exception relaying peer data back to browser",e);
                    LanternUtils.closeOnFlush(channel);
                    
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

    /**
     * Closes the specified channel after all queued write requests are flushed.
     */
    public static void closeOnFlush(final Channel ch) {
        LOG.info("Closing channel on flush: {}", ch);
        if (ch == null) {
            LOG.warn("Channel is NULL!!");
            return;
        }
        if (ch.isConnected()) {
            ch.write(ChannelBuffers.EMPTY_BUFFER).addListener(
                ChannelFutureListener.CLOSE);
        }
    }
    
    public static String getMacAddress() {
        if (MAC_ADDRESS != null) {
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
                    MAC_ADDRESS = Base64.encodeBase64String(mac).trim();
                    return MAC_ADDRESS;
                }
            } catch (final SocketException e) {
                LOG.warn("Could not get MAC address?");
            }
        }
        try {
            LOG.warn("Returning custom MAC address");
            MAC_ADDRESS = Base64.encodeBase64String(
                InetAddress.getLocalHost().getAddress()) + 
                System.currentTimeMillis();
            return MAC_ADDRESS;
        } catch (final UnknownHostException e) {
            final byte[] bytes = new byte[24];
            new Random().nextBytes(bytes);
            return Base64.encodeBase64String(bytes);
        }
    }
    

    public static File configDir() {
        return CONFIG_DIR;
    }
    
    public static boolean isTransferEncodingChunked(final HttpMessage m) {
        List<String> chunked = m.getHeaders(HttpHeaders.Names.TRANSFER_ENCODING);
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
}
