package org.lantern;

import static org.junit.Assert.*;

import java.util.concurrent.atomic.AtomicInteger;

import org.junit.Test;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;


public class NatPmpTest {

    @Test public void testNatPmp() throws Exception {
        // NOTE: This will of course only work from a network with a router
        // that support NAT-PMP! Disable for deploys in other scenarios?
        final NatPmp pmp = new NatPmp();
        final AtomicInteger ai = new AtomicInteger(-1);
        final PortMapListener portMapListener = new PortMapListener() {
            
            @Override
            public void onPortMapError() {
                System.out.println("Port map error!!");
            }
            
            @Override
            public void onPortMap(final int port) {
                ai.set(port);
                synchronized(ai) {
                    ai.notifyAll();
                }
            }
        };
        final int index = 
            pmp.addNatPmpMapping(PortMappingProtocol.TCP, 5678, 1341, portMapListener);
        assertTrue(index != -1);
        synchronized(ai) {
            if (ai.get() == -1) {
                ai.wait(2000);
            }
        }
        final int mapped = ai.get();
        assertTrue(mapped > 1024);
    }
}
