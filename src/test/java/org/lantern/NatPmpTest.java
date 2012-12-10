package org.lantern;

import static org.junit.Assert.assertTrue;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import org.junit.Test;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;


public class NatPmpTest {
    
    @Test 
    public void testNatPmp() throws Exception {
        // NOTE: This will of course only work from a network with a router
        // that supports NAT-PMP! Disable for deploys in other scenarios?
        final NatPmp pmp = 
            new NatPmp(TestUtils.getStatsTracker());
        final AtomicInteger ai = new AtomicInteger(-1);
        final AtomicBoolean error = new AtomicBoolean();
        final PortMapListener portMapListener = new PortMapListener() {
            
            @Override
            public void onPortMapError() {
                System.out.println("Port map error!!");
                error.set(true);
                synchronized(ai) {
                    ai.notifyAll();
                }
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
            pmp.addNatPmpMapping(PortMappingProtocol.TCP, 5678, 1341, 
                portMapListener);
        assertTrue(index != -1);
        synchronized(ai) {
            if (ai.get() == -1) {
                ai.wait(2000);
            }
        }
        if (!error.get()) {
            final int mapped = ai.get();
            assertTrue(mapped > 1024);
        }
    }
}
