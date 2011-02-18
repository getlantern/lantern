package org.lantern;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.net.UnknownHostException;
import java.util.Enumeration;
import java.util.Random;
import java.util.Set;
import java.util.zip.GZIPInputStream;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFutureListener;
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
    
    private static final Set<String> CENSORED = 
        Sets.newHashSet("China", "Iran", "Burma", "Vietnam", "Egypt", 
            "Bahrain", "Tunisia", "Syria", "Libya", "Venezuela");
    
    private static final File UNZIPPED = new File("GeoIP.dat");
    
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
    }
    
    public static boolean isCensored() {
        
        try {
            final LookupService cl = new LookupService(UNZIPPED,
                LookupService.GEOIP_MEMORY_CACHE);
            final Country country = 
                cl.getCountry(PublicIpAddress.getPublicIpAddress());
            LOG.info("Country is: {}", country);
            System.out.println(country.getName());
            return CENSORED.contains(country.getName());
        } catch (final IOException e) {
            return true;
        }
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
}
