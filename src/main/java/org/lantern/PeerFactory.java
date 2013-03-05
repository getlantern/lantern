package org.lantern;

import java.net.InetAddress;
import java.util.concurrent.ExecutorService;

import org.apache.commons.lang3.StringUtils;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;
import org.lantern.state.Peer;
import org.lantern.state.Peer.Type;
import org.lantern.state.Peers;
import org.lantern.util.LanternTrafficCounterHandler;
import org.lantern.util.ThreadPools;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Factory for creating peers that include data to be shown to the frontend.
 */
@Singleton
public class PeerFactory {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final ModelUtils modelUtils;
    private final Peers peers;

    /**
     * We create an executor here because we need to thread our geo-ip lookups.
     */
    private final ExecutorService exec = 
        ThreadPools.newCachedThreadPool("Peer-Factory-Thread-");

    private final Roster roster;

    @Inject
    public PeerFactory(final ModelUtils modelUtils, final Model model,
            final Roster roster) {
        this.modelUtils = modelUtils;
        this.roster = roster;
        this.peers = model.getPeerCollector();
    }
    
    public void addIncomingPeer(final InetAddress address, 
        final LanternTrafficCounterHandler trafficCounter) {
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

    public void addPeer(final String userId, final InetAddress address, 
        final int port, final Type type, final boolean incoming, 
        final LanternTrafficCounterHandler trafficCounter) {
        
        // We thread this because there's a geo IP lookup that could otherwise
        // stall the calling thread.
        exec.submit(new Runnable() {

            @Override
            public void run() {
                log.debug("Adding peer");
                final Peer existing;
                if (StringUtils.isNotBlank(userId)) {
                    existing = peers.getPeer(LanternUtils.newURI(userId));
                } else {
                    existing = peers.getPeer(address);

                }
                if (existing != null) {
                    log.debug("Peer already exists...");
                    
                    // It could have just been deserialized from disk, so we
                    // want to give it a real traffic counter.
                    final LanternTrafficCounterHandler tc = 
                        existing.getTrafficCounter();
                    if (tc != null) {
                        log.warn("Existing traffic counter?");
                    } else {
                        log.debug("Adding traffic counter...");
                        existing.setTrafficCounter(trafficCounter);
                    }
                } else {
                    final Peer peer = newGiveModePeer(userId, address, port,
                            type, incoming, trafficCounter);
                    peers.addPeer(address, peer);
                }
            }
            // Note we don't sync peers with the frontend here because the timer 
            // will do it for us
        });
    }
    

    private Peer newGetModePeer(final InetAddress address,
            final LanternTrafficCounterHandler trafficCounter) {
        final String hostAddress = address.getHostAddress();
        final GeoData geo = modelUtils.getGeoData(hostAddress);
        return new Peer("", geo.getCountrycode(), false, geo.getLatitude(), 
            geo.getLongitude(), Type.desktop, hostAddress, Mode.get, 
            true, trafficCounter, new LanternRosterEntry());
    }
    
    
    private Peer newGiveModePeer(final String userId, final InetAddress address, 
        final int port, final Type type, final boolean incoming, 
        final LanternTrafficCounterHandler trafficCounter) {
        
        final LanternRosterEntry entry;
        if (StringUtils.isNotBlank(userId)) {
            final LanternRosterEntry temp = this.roster.getRosterEntry(userId);
            if (temp != null) {
                entry = temp;
            } else {
                entry = new LanternRosterEntry();
            }
        } else {
            entry = new LanternRosterEntry();
        }
        

        final GeoData geo = modelUtils.getGeoData(address.getHostAddress());
        return new Peer(userId, geo.getCountrycode(), true, geo.getLatitude(), 
            geo.getLongitude(), type, address.getHostAddress(), Mode.give, 
            incoming, trafficCounter, entry);
    }
}
