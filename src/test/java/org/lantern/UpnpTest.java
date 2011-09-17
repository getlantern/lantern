package org.lantern;

import static org.junit.Assert.*;

import java.util.concurrent.atomic.AtomicBoolean;

import org.junit.Test;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;


public class UpnpTest {

    @Test public void testUpnp() throws Exception {
        System.setProperty("java.util.logging.config.file", 
            "src/test/resources/logging.properties");
        final Upnp up = new Upnp();
        final AtomicBoolean mapped = new AtomicBoolean(false);
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
        assertTrue(mapped.get());
    }
}
