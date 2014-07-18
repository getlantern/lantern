package org.lantern.util;

import static org.junit.Assert.assertTrue;

import java.io.File;
import java.io.FileInputStream;
import java.net.InetAddress;

import org.junit.Test;

public class GatewayUtilTest {

    @Test
    public void testFindGatewayNetstat() throws Exception {
        final File file = new File("src/test/resources/netstat.txt");
        final FileInputStream fis = new FileInputStream(file);
        final String gateway = GatewayUtil.findDefaultGatewayNetstat(fis);
        final InetAddress ia = InetAddress.getByName(gateway);
        System.err.println(gateway);
        assertTrue("Not a site local address", ia.isSiteLocalAddress());
    }
    
    @Test
    public void testFindGatewayWindows() throws Exception {
        final File file = new File("src/test/resources/ipconfig.txt");
        final FileInputStream fis = new FileInputStream(file);
        final String gateway = GatewayUtil.findDefaultGatewayWindows(fis);
        final InetAddress ia = InetAddress.getByName(gateway);
        assertTrue("Not a site local address", ia.isSiteLocalAddress());
    }

}
