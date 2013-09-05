package org.lantern.util;

import static org.junit.Assert.*;

import java.net.InetAddress;

import org.junit.Test;

public class NetworkTest {
    @Test
    public void testOnSameNetwork() throws Exception {
        InetAddress address1 = InetAddress.getByName("254.254.254.254");
        InetAddress address2 = InetAddress.getByName("254.254.254.255");
        InetAddress address3 = InetAddress.getByName("254.254.255.255");
        InetAddress address4 = InetAddress.getByName("254.255.255.255");
        InetAddress address5 = InetAddress.getByName("255.255.255.255");

        assertTrue(Network.onSameNetwork(address1, address2, 24));
        assertFalse(Network.onSameNetwork(address1, address2, 32));

        assertTrue(Network.onSameNetwork(address2, address3, 16));
        assertFalse(Network.onSameNetwork(address2, address3, 24));

        assertTrue(Network.onSameNetwork(address3, address4, 8));
        assertFalse(Network.onSameNetwork(address3, address4, 16));

        assertTrue(Network.onSameNetwork(address4, address5, 0));
        assertFalse(Network.onSameNetwork(address4, address5, 4));
    }

    @Test
    public void testOnLocalNetwork() throws Exception {
        InetAddress localhost = Network.firstLocalNonLoopbackIPv4Address();
        assertTrue(Network.isOnLocalNetwork(localhost));

        InetAddress googleDns = InetAddress.getByName("8.8.8.8");
        assertFalse(Network.isOnLocalNetwork(googleDns));
    }
}
