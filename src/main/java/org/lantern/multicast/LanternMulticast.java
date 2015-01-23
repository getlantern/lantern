package org.lantern.multicast;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.net.DatagramPacket;
import java.net.InetAddress;
import java.net.MulticastSocket;
import java.util.Collection;
import java.util.HashSet;
import java.util.Timer;
import java.util.TimerTask;

import org.lantern.JsonUtils;
import org.lantern.LanternUtils;
import org.lantern.event.Events;
import org.lantern.state.StaticSettings;
import org.lantern.state.SyncPath;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Charsets;

/**
 * Uses multicast to detect other Lanterns on the local network.
 */
public class LanternMulticast {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    public static final int MC_PORT = 9864;
    
    public static final String MC_ADDR = "232.77.77.77";
    
    private final int sendPort;
    
    
    private final Collection<String> endpoints = new HashSet<String>();
    
    public LanternMulticast() {
        this(MC_PORT);
    }

    public LanternMulticast(final int port) {
        this.sendPort = port;
    }

    public void join() {
        try {
            final InetAddress group = InetAddress.getByName(MC_ADDR);
            final MulticastSocket ms = new MulticastSocket(MC_PORT);
            ms.joinGroup(group);
            
            if (LanternUtils.shouldAdvertizeOnLocalNetwork()) {
                sendHellos(group, ms);
                addShutdownHook(group, ms);
            }
            
            listen(ms);
        } catch (final IOException e) {
            log.error("Error starting multicast?", e);
        }
    }

    /**
     * Periodically announce ourselves to the network.
     * 
     * @param group The multicast group.
     * @param ms The multicast socket.
     */
    private void sendHellos(final InetAddress group, final MulticastSocket ms) {
        final Timer t = new Timer("Multicast-Send", true);
        t.schedule(new TimerTask() {
            
            @Override
            public void run() {
                final MulticastMessage mm = 
                        MulticastMessage.newHello(StaticSettings.getLocalEndpoint());
                send(ms, mm, group);
            }
        }, 1000, 10*1000);
    }

    private void addShutdownHook(final InetAddress group, 
            final MulticastSocket ms) {
        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {

            @Override
            public void run() {
                final MulticastMessage mm = 
                        MulticastMessage.newBye(StaticSettings.getLocalEndpoint());
                send(ms, mm, group);
            }
            
        }, "Multicast-Leave"));
    }

    private void send(final MulticastSocket ms, final MulticastMessage mm, 
            final InetAddress group) {
        final String msg = JsonUtils.jsonify(mm);
        final DatagramPacket dp = 
                new DatagramPacket(msg.getBytes(Charsets.UTF_8), msg.length(),
                                    group, sendPort);
        try {
            ms.send(dp);
        } catch (final IOException e) {
            log.error("Could not leave group", e);
        }
    }

    private void listen(final MulticastSocket ms) {
        final Runnable run = new Runnable() {

            @Override
            public void run() {
                while (true) {
                    final byte[] buf = new byte[1000];
                    final DatagramPacket recv = new DatagramPacket(buf, buf.length);
                    try {
                        // Note that this call blocks.
                        ms.receive(recv);
                        final MulticastMessage msg = 
                                JsonUtils.decode(new ByteArrayInputStream(buf), 
                                        MulticastMessage.class);
                        final String endpoint = msg.getEndpoint();
                        if (StaticSettings.getLocalEndpoint().equals(endpoint)) {
                            log.info("Ignoring messages from ourselves");
                            continue;
                        }
                        if (msg.isBye()) {
                            endpoints.remove(msg.getEndpoint());
                        } else {
                            endpoints.add(msg.getEndpoint());
                        }
                        Events.sync(SyncPath.LOCAL_LANTERNS, endpoints);
                    } catch (final IOException e) {
                        log.error("Error receiving multicast?", e);
                    }
                }
            }
        };
        final Thread listen = new Thread(run, "Multicast-Listening");
        listen.setDaemon(true);
        listen.start();
    }

}
