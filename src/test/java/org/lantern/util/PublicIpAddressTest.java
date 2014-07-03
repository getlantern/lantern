package org.lantern.util;

import java.net.InetAddress;

import org.junit.Test;

public class PublicIpAddressTest {
    @Test
    public void testPublicIp() {
        PublicIpAddress pip = new PublicIpAddress();
        InetAddress address = pip.getPublicIpAddress();
        System.out.println(address);
    }
}
