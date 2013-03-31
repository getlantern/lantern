package org.lantern;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.URI;
import java.security.cert.CertificateEncodingException;
import java.security.cert.X509Certificate;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang3.StringUtils;
import org.jboss.netty.channel.Channel;
import org.jivesoftware.smack.packet.Presence;
import org.lantern.event.Events;
import org.lantern.event.IncomingPeerEvent;
import org.lantern.event.KscopeAdEvent;
import org.lantern.event.PeerCertEvent;
import org.lantern.event.UpdatePresenceEvent;
import org.lantern.kscope.LanternKscopeAdvertisement;
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

import com.google.common.eventbus.Subscribe;
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
        Events.register(this);
    }

    
    /** 
     * There are two ways we initially learn about new peers. The first is a
     * Lantern peer directly on our roster, which will produce this event. The
     * second is a kaleidoscope advertisement. Those Kaleidoscope
     * advertisements can be from peers on our roster, but they can also be
     * from peers we're not directly connected to. This method captures the
     * first case where peers on our roster are running Lantern.
     * 
     * @param event The update presence event.
     */
    @Subscribe
    public void onUpdatePresenceEvent(final UpdatePresenceEvent event) {
        log.debug("Processing presence event");
        final Presence presence = event.getPresence();
        final String from = presence.getFrom();
        if (StringUtils.isBlank(from)) {
            log.warn("Presence with blank from?");
        } else {
            addPeer(LanternUtils.newURI(from), Type.pc);
        }
    }
    
    @Subscribe
    public void onKscopeAd(final KscopeAdEvent event) {
        final LanternKscopeAdvertisement ad = event.getAd();
        // It is possible and even likely we already know about this peer
        // through some other means, in which case we have to update the data
        // about that peer as necessary.
        log.debug("Adding peer through kscop add...");
        final String jid = ad.getJid();
        final URI uri = LanternUtils.newURI(jid);
        final Peer existing = this.peers.getPeer(uri);
        final LanternRosterEntry entry = this.roster.getRosterEntry(jid);
        if (existing == null) {
            // The following can be null.
            final Peer peer = new Peer(uri, "", 
                    ad.hasMappedEndpoint(), 0, 0, Type.pc, ad.getAddress(), 
                    ad.getPort(), Mode.give, false, null, entry);
            this.peers.addPeer(uri, peer);
            updateGeoData(peer, ad.getAddress());
        } else {
            existing.setIp(ad.getAddress());
            existing.setPort(ad.getPort());
            existing.setMode(Mode.give);
            existing.setMapped(ad.hasMappedEndpoint());
            if (existing.getRosterEntry() == null) {
                // Ours could be null too, but can't hurt to set.
                existing.setRosterEntry(entry);
            }
            existing.setVersion(ad.getLanternVersion());
            updateGeoData(existing, ad.getAddress());
        }
    }
    


    private void updateGeoData(final Peer peer, final InetAddress address) {
        updateGeoData(peer, address.getHostAddress());
    }
    
    private void updateGeoData(final Peer peer, final String address) {
        if (StringUtils.isNotBlank(peer.getCountry())) {
            log.debug("Peer already had geo data: {}", peer);
            return;
        }
        
        final Runnable runner = new Runnable() {

            @Override
            public void run() {
                final GeoData geo = modelUtils.getGeoData(address);
                peer.setCountry(geo.getCountrycode());
                peer.setLat(geo.getLatitude());
                peer.setLon(geo.getLongitude());
            }
        };
        this.exec.submit(runner);
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
    /*
    @Override
    public void onIncomingConnection(final URI fullJid, final InetSocketAddress isa,
        final LanternTrafficCounter trafficCounter) {
        // There should always be an existing peer at this point,
        // and we should add data to that peer. Incoming peers should always
        // be of type pc.
        updatePeer(fullJid, isa, Type.pc, trafficCounter);
    }
    */

    private void updatePeer(final URI fullJid, final InetSocketAddress isa,
            final Type type, final LanternTrafficCounter trafficCounter) {
        final Peer peer = peers.getPeer(fullJid);
        if (peer == null) {
            log.warn("No peer for {}", fullJid);
            return;
        }
        updatePeer(peer, isa, type, trafficCounter);
    }
    
    private void updatePeer(final Peer peer, final InetSocketAddress isa,
            final Type type, final LanternTrafficCounter trafficCounter) {
        // We can get multiple notifications for the same peer, in which case
        // they'll already have a counter.
        if (peer.getTrafficCounter() == null) {
            peer.setTrafficCounter(trafficCounter);
        }
        final String address = isa.getAddress().getHostAddress();
        if (StringUtils.isBlank(peer.getIp())) {
            peer.setIp(address);
        }
        if (peer.getPort() == 0) {
            peer.setPort(isa.getPort());
        }
        peer.setType(type.toString());
        updateGeoData(peer, isa.getAddress());
        // Note we don't sync peers with the frontend here because the timer
        // will do it for us
    }


    @Override
    public void onOutgoingConnection(final URI fullJid,
        final InetSocketAddress isa, final Type type,
        final LanternTrafficCounter trafficCounter) {
        updatePeer(fullJid, isa, type, trafficCounter);
    }
    
    @Override
    public void addPeer(final URI fullJid, final Type type) {
        
        // This is a peer we know very little about at this point, as we 
        // haven't made any network connections with them.
        final LanternRosterEntry entry = rosterEntry(fullJid);

        final Peer existing = peers.getPeer(fullJid);
        
        if (existing != null) {
            log.debug("Peer already exists...");
        } else {
            log.debug("Adding peer {}", fullJid);
            final Peer peer = new Peer(fullJid, "", false, 0L, 0L, type, 
                    "", 0, Mode.none, false, null, entry);
            peers.addPeer(fullJid, peer);
        }
    }
    
    private LanternRosterEntry rosterEntry(final URI fullJid) {
        return this.roster.getRosterEntry(fullJid.toASCIIString());
    }
    
    private final Map<String, Peer> certsToPeers = 
            new ConcurrentHashMap<String, Peer>();
    
    @Subscribe
    public void onCert(final PeerCertEvent event) {
        final Peer peer = this.peers.getPeer(event.getJid());
        if (peer == null) {
            log.error("Got a cert for peer we don't know about? " +
                "{} not found in {}", event.getJid(), this.peers.getPeers().keySet());
        } else {
            certsToPeers.put(event.getBase64Cert(), peer);
        }
    }

    @Subscribe
    public void onIncomingPeerEvent(final IncomingPeerEvent event) {
        // First we have to figure out which peer this is an incoming socket
        // for base on the certificate.
        final X509Certificate cert = event.getCert();
        final Channel channel = event.getChannel();
        final LanternTrafficCounter counter = event.getTrafficCounter();
        try {
            final String base64Cert = 
                    Base64.encodeBase64String(cert.getEncoded());
            final Peer peer = certsToPeers.get(base64Cert);
            if (peer == null) {
                log.error("No matching peer for cert: {} in {}", base64Cert, 
                    certsToPeers);
                return;
            }
            updatePeer(peer, (InetSocketAddress)channel.getRemoteAddress(), 
                Type.pc, counter);
        } catch (final CertificateEncodingException e) {
            log.error("Could not encode certificate?", e);
        }
    }
}
