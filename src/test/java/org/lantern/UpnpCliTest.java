package org.lantern;

import static org.junit.Assert.*;

import java.util.concurrent.atomic.AtomicBoolean;

import org.junit.Test;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;

public class UpnpCliTest {

    @Test
    public void test() throws Exception {
        final UpnpCli cli = new UpnpCli();
        
        final Object block = new Object();
        final AtomicBoolean error = new AtomicBoolean();
        final AtomicBoolean success = new AtomicBoolean();
        final PortMapListener portMapListener = new PortMapListener() {
            
            @Override
            public void onPortMapError() {
                synchronized (block) {
                    error.set(true);
                    block.notifyAll();
                }
            }
            
            @Override
            public void onPortMap(int externalPort) {
                synchronized (block) {
                    success.set(true);
                    block.notifyAll();
                }
            }
        };
        synchronized (block) {
            cli.addUpnpMapping(PortMappingProtocol.TCP, 7777, 443, portMapListener);
            
            if (!success.get() && !error.get()) {
                block.wait(11000);
            }
            assertTrue(error.get() || success.get());
        }
    }

}
