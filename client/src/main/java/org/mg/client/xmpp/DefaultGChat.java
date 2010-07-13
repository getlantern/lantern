package org.mg.client.xmpp;

import java.util.Collection;
import java.util.HashSet;

import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.PacketListener;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Packet;
import org.jivesoftware.smack.packet.Presence;

/**
 * Default implementation of GChat integration.
 */
public class DefaultGChat implements GChat {

    /**
     * Unique property representing the public IP address of an MG user.
     */
    private static final String MG_IP = "mgip";
    
    private final Collection<Packet> mgPackets = new HashSet<Packet>();
    
    public void connect(final String userName, final String password,
        final String ip) throws XMPPException {
        final ConnectionConfiguration config = 
            new ConnectionConfiguration("talk.google.com", 5222, "gmail.com");
        config.setCompressionEnabled(true);
        final XMPPConnection conn = new XMPPConnection(config);
        conn.connect();
        conn.login(userName, password);
        conn.addPacketListener(new PacketListener() {
            public void processPacket(final Packet pack) {
                final Collection<String> names = pack.getPropertyNames();
                if (names.contains(MG_IP)) {
                    System.out.println("PACKET: "+pack);
                    System.out.println(pack.getFrom());
                    System.out.println(pack.getProperty(MG_IP));
                    mgPackets.add(pack);
                }
            }
        }, null);
        
        final Presence presence = new Presence(Presence.Type.available);
        presence.setProperty(MG_IP, ip);
        conn.sendPacket(presence);
    }

    public Collection<String> getAllIps() {
        final Collection<String> ips = new HashSet<String>();
        synchronized (mgPackets) {
            for (final Packet p : mgPackets) {
                ips.add((String) p.getProperty(MG_IP));
            }
        }
        return ips;
    }
}
