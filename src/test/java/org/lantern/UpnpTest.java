package org.lantern;

import java.util.concurrent.atomic.AtomicBoolean;

import org.junit.Test;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;


public class UpnpTest {

    @Test public void testUpnp() throws Exception {
        System.setProperty("java.util.logging.config.file", 
            "src/test/resources/logging.properties");
        final Upnp up = new Upnp(TestUtils.getStatsTracker());
        final AtomicBoolean mapped = new AtomicBoolean(false);
        final AtomicBoolean error = new AtomicBoolean(false);
        final PortMapListener pml = new PortMapListener() {
            @Override
            public void onPortMapError() {
                System.out.println("ERROR!!");
                synchronized (mapped) {
                    mapped.notifyAll();
                }
            }
            
            @Override
            public void onPortMap(final int port) {
                System.out.println("Got port mapped!!"+port);
                mapped.set(true);
                synchronized (mapped) {
                    mapped.notifyAll();
                }
            }
        };
        up.addUpnpMapping(PortMappingProtocol.TCP, 65522, 65522, pml);
        synchronized (mapped) {
            if (!mapped.get()) {
                mapped.wait(4000);
            }
        }
        
        // We might not be running on a router that supports UPnP
        if (!error.get()) {
            // We don't necessarily get an error even if the router doesn't
            // support UPnP.
            //assertTrue(mapped.get());
        }
    }
}
