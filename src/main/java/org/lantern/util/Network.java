package org.lantern.util;

import java.net.InetAddress;
import java.net.InterfaceAddress;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.net.UnknownHostException;
import java.util.BitSet;
import java.util.Enumeration;

public class Network {
    /**
     * Determine whether the given address is on our local network.
     * 
     * @param address
     * @return
     * @throws SocketException
     * @throws UnknownHostException
     */
    public static boolean isOnLocalNetwork(InetAddress address) {
        try {
            Enumeration<NetworkInterface> networkInterfaces = NetworkInterface
                    .getNetworkInterfaces();
            while (networkInterfaces.hasMoreElements()) {
                NetworkInterface networkInterface = networkInterfaces
                        .nextElement();
                for (InterfaceAddress ifAddress : networkInterface
                        .getInterfaceAddresses()) {
                    int networkPrefixLength = ifAddress
                            .getNetworkPrefixLength();
                    if (networkPrefixLength > 0 && networkPrefixLength <= 32) {
                        // Only do networks with some sort of prefix, and avoid
                        // IPv6
                        if (onSameNetwork(address, ifAddress.getAddress(),
                                networkPrefixLength)) {
                            return true;
                        }
                    }
                }
            }
            return false;
        } catch (Exception e) {
            return false;
        }
    }

    public static boolean isOnLocalNetwork(String address) {
        try {
            return isOnLocalNetwork(InetAddress.getByName(address));
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Based on
     * http://stackoverflow.com/questions/8555847/test-with-java-if-two-
     * ips-are-in-the-same-network.
     * 
     * @param address1
     * @param address2
     * @param networkPrefixLength
     * @return
     */
    public static boolean onSameNetwork(InetAddress address1,
            InetAddress address2, int networkPrefixLength) {
        BitSet s1 = BitSet.valueOf(address1.getAddress());
        BitSet s2 = BitSet.valueOf(address2.getAddress());
        BitSet mask = new BitSet(networkPrefixLength);
        mask.set(0, networkPrefixLength);

        s1.and(mask);
        s2.and(mask);

        return s1.equals(s2);
    }

    public static InetAddress firstLocalNonLoopbackIPv4Address()
            throws SocketException {
        Enumeration<NetworkInterface> networkInterfaces = NetworkInterface
                .getNetworkInterfaces();
        while (networkInterfaces.hasMoreElements()) {
            NetworkInterface networkInterface = networkInterfaces.nextElement();
            for (InterfaceAddress ifAddress : networkInterface
                    .getInterfaceAddresses()) {
                if (ifAddress.getNetworkPrefixLength() > 0
                        && ifAddress.getNetworkPrefixLength() <= 32
                        && !ifAddress.getAddress().isLoopbackAddress()) {
                    return ifAddress.getAddress();
                }
            }
        }
        return null;
    }

}
