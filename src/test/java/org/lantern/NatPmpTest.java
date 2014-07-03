package org.lantern;

import static org.junit.Assert.*;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import org.junit.Ignore;
import org.junit.Test;
import org.lantern.state.Model;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.littleshoot.util.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

// Skipping this test because I'm not sure how legit it is.  On my home network,
// I get mapped ports that are below 1024.  I think a better test would be to
// try to map a port and if it all looks like it worked, test to make sure that
// we can talk to a service listening on that port.
@Ignore
public class NatPmpTest {
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Test 
    public void testNatPmp() throws Exception {
        if (NetworkUtils.isPublicAddress()) {
            log.debug("Not testing NAT-PMP on public network");
            return;
        }

        final NatPmpImpl pmp = new NatPmpImpl(new Model());
        final AtomicInteger ai = new AtomicInteger(-1);
        final AtomicBoolean error = new AtomicBoolean();
        final PortMapListener portMapListener = new PortMapListener() {
            
            @Override
            public void onPortMapError() {
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
                ai.wait(12000);
            }
        }

        if (!error.get()) {
            final int mapped = ai.get();
            if (mapped == 0) {
                //we got nothing back from the network, so the network must
                //not support NatPMP
            } else {
                assertTrue("Expected a mapped port", mapped > 1024);
            }
        } else {
            log.debug("Network does not support NAT-PMP so we're not testing it.");
        }
    }
}
