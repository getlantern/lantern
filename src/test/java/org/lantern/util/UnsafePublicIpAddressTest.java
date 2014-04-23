package org.lantern.util;

import static org.junit.Assert.*;

import java.net.InetAddress;

import org.junit.Test;

public class UnsafePublicIpAddressTest {
    @Test
    public void testGetIp() {
        UnsafePublicIpAddress upia = new UnsafePublicIpAddress();
        InetAddress address = upia.getPublicIpAddress();
        assertNotNull(address);
    }
}
