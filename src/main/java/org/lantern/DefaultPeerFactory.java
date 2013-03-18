package org.lantern;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.util.concurrent.ExecutorService;

import org.apache.commons.lang3.StringUtils;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;
import org.lantern.state.Peer;
import org.lantern.state.Peer.Type;
import org.lantern.state.Peers;
import org.lantern.util.LanternTrafficCounter;
import org.lantern.util.Threads;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Factory for creating peers that include data to be shown to the frontend.
 */
@Singleton
public class DefaultPeerFactory implements PeerFactory {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final ModelUtils modelUtils;
    private final Peers peers;

    /**
     * We create an executor here because we need to thread our geo-ip lookups.
     */
    private final ExecutorService exec = 
        Threads.newCachedThreadPool("Peer-Factory-Thread-");

    private final Roster roster;

    @Inject
    public DefaultPeerFactory(final ModelUtils modelUtils, final Model model,
            final Roster roster) {
        this.modelUtils = modelUtils;
        this.roster = roster;
        this.peers = model.getPeerCollector();
    }
    
    /**
     * Adds an incoming peer. Note that this method purely uses the address
     * of the incoming peer and not the JID. For the case of port-mapped peers,
     * this will be accurate because the remote address is in fact the address
     * of the peer. For p2p connections, however, there's an intermediary 
     * step where we typically copy data from a temporary local server to the 
     * local HTTP server, for the purposes of making ICE work more simply 
     * (i.e. that way the HTTP server doesn't have to worry about ICE but 
     * rather just about servicing incoming sockets). The problem is that if 
     * this method is used to add those peers, their IP address will always 
     * be the IP address of localhost, so they will not be mapped correctly. 
     * Their data will be tracked correctly, however. 
     * 
     * See:
     * 
     * https://github.com/adamfisk/littleshoot-util/blob/master/src/main/java/org/littleshoot/util/RelayingSocketHandler.java
     * 
     * @param address The address of the peer.
     * @param trafficCounter The counter for keeping track of traffic to and
     * from the peer.
     */
    @Override
    public void addIncomingPeer(final InetAddress address, 
        final LanternTrafficCounter trafficCounter) {
        exec.submit(new Runnable() {
            @Override
            public void run() {
                final Peer peer = newGetModePeer(address, trafficCounter);
                peers.addPeer(address, peer);
            }
        });
        // Note we don't sync peers with the frontend here because the timer 
        // will do it for us
    }
    
    @Override
    public void addOutgoingPeer(final String fullJid, 
        final InetSocketAddress isa, final Type type, 
        final LanternTrafficCounter trafficCounter) {
        addPeer(fullJid, isa.getAddress(), isa.getPort(), type, false, 
            trafficCounter);
    }

    private void addPeer(final String fullJid, final InetAddress address, 
        final int port, final Type type, final boolean incoming, 
        final LanternTrafficCounter trafficCounter) {
        
        // We thread this because there's a geo IP lookup that could otherwise
        // stall the calling thread.
        exec.submit(new Runnable() {

            @Override
            public void run() {
                log.debug("Adding peer");
                final Peer existing;
                if (StringUtils.isNotBlank(fullJid)) {
                    existing = peers.getPeer(LanternUtils.newURI(fullJid));
                } else {
                    existing = peers.getPeer(address);

                }
                if (existing != null) {
                    log.debug("Peer already exists...");
                    
                    // It could have just been deserialized from disk, so we
                    // want to give it a real traffic counter.
                    final LanternTrafficCounter tc = 
                        existing.getTrafficCounter();
                    if (tc != null) {
                        log.warn("Existing traffic counter?");
                    } else {
                        log.debug("Adding traffic counter...");
                        existing.setTrafficCounter(trafficCounter);
                    }
                } else {
                    final Peer peer = newGiveModePeer(fullJid, address, port,
                            type, incoming, trafficCounter);
                    peers.addPeer(address, peer);
                }
            }
            // Note we don't sync peers with the frontend here because the timer 
            // will do it for us
        });
    }
    

    private Peer newGetModePeer(final InetAddress address,
            final LanternTrafficCounter trafficCounter) {
        final String hostAddress = address.getHostAddress();
        final GeoData geo = modelUtils.getGeoData(hostAddress);
        return new Peer("", geo.getCountrycode(), false, geo.getLatitude(), 
            geo.getLongitude(), Type.desktop, hostAddress, Mode.get, 
            true, trafficCounter, null);
    }
    
    
    private Peer newGiveModePeer(final String fullJid, final InetAddress address, 
        final int port, final Type type, final boolean incoming, 
        final LanternTrafficCounter trafficCounter) {
        final LanternRosterEntry entry = rosterEntry(fullJid);

        final GeoData geo = modelUtils.getGeoData(address.getHostAddress());
        return new Peer(fullJid, geo.getCountrycode(), true, geo.getLatitude(), 
            geo.getLongitude(), type, address.getHostAddress(), Mode.give, 
            incoming, trafficCounter, entry);
    }

    private LanternRosterEntry rosterEntry(final String fullJid) {
        if (StringUtils.isNotBlank(fullJid)) {
            return this.roster.getRosterEntry(fullJid);
        }
        return null;
    }
}
