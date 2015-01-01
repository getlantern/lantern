package org.lantern.multicast;

import static org.junit.Assert.*;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.net.DatagramPacket;
import java.net.InetAddress;
import java.net.MulticastSocket;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.Test;
import org.lantern.JsonUtils;

public class LanternMulticastTest {

    @Test
    public void test() throws Exception {
        final InetAddress group = InetAddress.getByName(LanternMulticast.MC_ADDR);
        final MulticastSocket ms = new MulticastSocket(0);
        ms.joinGroup(group);
        
        final AtomicReference<MulticastMessage> ref = 
                new AtomicReference<MulticastMessage>();
        listen(ms, ref);
        final LanternMulticast lm = 
                new LanternMulticast(ms.getLocalPort(), LanternMulticast.MC_PORT);
        
        synchronized (ref) {
            if (ref.get() == null) {
                ref.wait(6000);
            }
        }
        assertTrue(ref.get() != null);
    }
    
    private void listen(final MulticastSocket ms, 
            final AtomicReference<MulticastMessage> ref) {
        final Runnable run = new Runnable() {

            @Override
            public void run() {
                while (true) {
                    final byte[] buf = new byte[1000];
                    final DatagramPacket recv = new DatagramPacket(buf, buf.length);
                    try {
                        ms.receive(recv);
                        System.out.println("GOT PACKET: "+new String(buf));
                        final MulticastMessage msg = 
                                JsonUtils.decode(new ByteArrayInputStream(buf), 
                                        MulticastMessage.class);
                        synchronized (ref) {
                            ref.set(msg);
                            ref.notifyAll();
                        }
                        if (msg.isBye()) {
                        } else {
                        }
                    } catch (final IOException e) {
                    }
                }
            }
        };
        final Thread listen = new Thread(run, "Multicast-Listening");
        listen.setDaemon(true);
        listen.start();
    }

}
