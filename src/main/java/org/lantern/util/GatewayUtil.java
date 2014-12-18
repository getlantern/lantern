package org.lantern.util;

import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.UnknownHostException;
import java.util.Scanner;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.SystemUtils;
import org.lantern.NativeUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * A utility class for identifying the user's default network gateway and
 * opening it in the default browser.
 */
public class GatewayUtil {

    private static final Logger LOG = 
            LoggerFactory.getLogger(GatewayUtil.class);
    
    /**
     * Open the gateway configuration page in the default browser. This
     * attempts to automatically identify the gateway before opening it.
     * 
     * @throws IOException If there's an IO error in the native calls to get
     * gateway information.
     * @throws InterruptedException If the program is interrupted waiting for
     * the native calls.
     */
    public static void openGateway() throws IOException, InterruptedException {
        final String gateway = defaultGateway();
        LOG.debug("Found gateway: {}", gateway);
        NativeUtils.openUri("http://"+gateway);
    }

    /**
     * Utility method for determining the IP address of the default gateway.
     * 
     * @return The IP address of the default network gateway.
     * @throws IOException If there's an IO error running native commands.
     * @throws InterruptedException If a native command is interrupted.
     */
    public static String defaultGateway() throws IOException,
        InterruptedException {
        final String gateway;
        if (SystemUtils.IS_OS_WINDOWS) {
            gateway = findDefaultGatewayWindows();
        } else {
            gateway = findDefaultGatewayNetstat();
        }
        
        // Make sure we can actually connect to the config screen.
        final Socket sock = new Socket();
        try {
            sock.connect(new InetSocketAddress(gateway, 80), 6000);
        } finally {
            IOUtils.closeQuietly(sock);
        }
        return gateway;
    }

    /**
     * Utility method for determining the IP address of the default gateway on
     * any system with netstat.
     * 
     * @return The IP address of the default network gateway.
     * @throws IOException If there's an IO error running native commands.
     * @throws InterruptedException If a native command is interrupted.
     */
    public static String findDefaultGatewayNetstat() throws IOException, 
        InterruptedException {
        return findDefaultGatewayNetstat(defaultGatewayStream("netstat -nr"));
    }

    /**
     * Utility method for determining the IP address of the default gateway on
     * Windows.
     * 
     * @return The IP address of the default network gateway.
     * @throws IOException If there's an IO error running native commands.
     * @throws InterruptedException If a native command is interrupted.
     */
    public static String findDefaultGatewayWindows() throws IOException, 
        InterruptedException {
        return findDefaultGatewayWindows(defaultGatewayStream("ipconfig.exe"));
    }

    /**
     * Utility method for determining the IP address of the default gateway
     * from a netstat data stream. Can be on a live system or using test output.
     * 
     * @return The IP address of the default network gateway.
     * @throws IOException If there's an IO error running native commands.
     * @throws InterruptedException If a native command is interrupted.
     */
    public static String findDefaultGatewayNetstat(final InputStream is) {
        final Scanner scanner = new Scanner(is);
        scanner.useDelimiter("\n");
        while (scanner.hasNext()) {
            final String cur = scanner.next().toLowerCase().trim();
            if (cur.startsWith("default")) {
                final String[] strs = cur.split("\\s+");
                final String ip = strs[1];
                LOG.debug("IP of gateway is {}", ip);
                return ip;
            }
        }
        return "";
    }
    
    /**
     * Utility method for determining the IP address of the default gateway on
     * Windows given the relevant ipconfig.exe data or a test stream.
     * 
     * @return The IP address of the default network gateway.
     * @throws IOException If there's an IO error running native commands.
     * @throws InterruptedException If a native command is interrupted.
     */
    public static String findDefaultGatewayWindows(final InputStream is) {
        final Scanner scanner = new Scanner(is);
        scanner.useDelimiter("\n");
        while (scanner.hasNext()) {
            final String cur = scanner.next().toLowerCase().trim();
            if (cur.startsWith("default gateway")) {
                final String[] strs = cur.split(":");
                for (final String str : strs) {
                    try {
                        final InetAddress ia = InetAddress.getByName(str.trim());
                        if (ia.isSiteLocalAddress()) {
                            final String ip = ia.getHostAddress();
                            LOG.debug("IP of gateway is {}", ip);
                            return ip;
                        }
                    } catch (final UnknownHostException e) {
                        continue;
                    }
                }
            }
        }
        return "";
    }
    
    /**
     * Utility method for returning the default gateway data depending on the
     * operating system, for example netstat data for Unix systems and
     * ipconfig.exe data for Windows.
     * 
     * @param command The command to run.
     * @return The output.
     * @throws IOException If there's an IO error running the native command.
     * @throws InterruptedException If the native command is interrupted.
     */
    private static InputStream defaultGatewayStream(final String command) 
            throws IOException, InterruptedException {
        final Process gateway = Runtime.getRuntime().exec(command);
        
        final int result = gateway.waitFor();
        if (result == 0) {
            return gateway.getInputStream();
        }
        throw new IOException("The process returned the following error code: "+result);
    }
}
