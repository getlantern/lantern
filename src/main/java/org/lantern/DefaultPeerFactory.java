package org.lantern;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.URI;
import java.security.cert.CertificateEncodingException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import javax.net.ssl.SSLPeerUnverifiedException;
import javax.net.ssl.SSLSession;
import javax.security.cert.CertificateException;
import javax.security.cert.X509Certificate;

import org.apache.commons.lang3.StringUtils;
import org.jivesoftware.smack.packet.Presence;
import org.lantern.event.Events;
import org.lantern.event.KscopeAdEvent;
import org.lantern.event.PeerCertEvent;
import org.lantern.event.UpdatePresenceEvent;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.geoip.GeoData;
import org.lantern.kscope.LanternKscopeAdvertisement;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.state.Peer;
import org.lantern.state.Peer.Type;
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

    private final Roster roster;

    private final Model model;

    private final GeoIpLookupService geoIpLookupService;


    @Inject
    public DefaultPeerFactory(final GeoIpLookupService geoIpLookupService,
            final Model model,
            final Roster roster) {
        this.model = model;
        this.geoIpLookupService = geoIpLookupService;
        this.roster = roster;
        Events.register(this);
    }

    /**
     * There are two ways we initially learn about new peers. The first is a
     * Lantern peer directly on our roster, which will produce this event. The
     * second is a kaleidoscope advertisement. Those Kaleidoscope advertisements
     * can be from peers on our roster, but they can also be from peers we're
     * not directly connected to. This method captures the first case where
     * peers on our roster are running Lantern.
     * 
     * @param event
     *            The update presence event.
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
        log.debug("Adding peer through kscope ad...");
        final String jid = ad.getJid();
        final URI uri = LanternUtils.newURI(jid);
        final Peer existing = this.model.getPeerCollector().getPeer(uri);
        final LanternRosterEntry entry = this.roster.getRosterEntry(jid);
        if (existing == null) {
            // The following can be null.
            final Peer peer = new Peer(uri, "",
                    ad.hasMappedEndpoint(), 0, 0, Type.pc, ad.getAddress(),
                    ad.getPort(), Mode.give, false, entry);
            this.model.getPeerCollector().addPeer(uri, peer);
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

    public void updateGeoData(final Peer peer, final InetAddress address) {
        updateGeoData(peer, address.getHostAddress());
    }
      
    @Override
    public void updateGeoData(final Peer peer, final String address) {
        if (peer.hasGeoData()) {
          log.debug("Peer already had geo data: {}", peer);
          return;
        }

        final GeoData geo = this.geoIpLookupService.getGeoData(address);
        peer.setCountry(geo.getCountry().getIsoCode());
        peer.setLat(geo.getLocation().getLatitude());
        peer.setLon(geo.getLocation().getLongitude());
    }


    private void updatePeer(final URI fullJid, final InetSocketAddress isa,
            final Type type) {
        final Peer peer = this.model.getPeerCollector().getPeer(fullJid);
        if (peer == null) {
            log.warn("No peer for {}", fullJid);
            return;
        }
        updatePeer(peer, isa, type);
    }

    private void updatePeer(final Peer peer, final InetSocketAddress isa,
            final Type type) {
        final String address = isa.getAddress().getHostAddress();
        if (StringUtils.isBlank(peer.getIp())) {
            peer.setIp(address);
        }
        if (peer.getPort() == 0) {
            peer.setPort(isa.getPort());
        }
        if (peer.getRosterEntry() == null) {
            log.debug("Setting roster entry");
            final URI uri = LanternUtils.newURI(peer.getPeerid());
            peer.setRosterEntry(rosterEntry(uri));
        }
        peer.setType(type.toString());
        // Note we don't sync peers with the frontend here because the timer
        // will do it for us
    }

    @Override
    public void onOutgoingConnection(final URI fullJid,
            final InetSocketAddress isa, final Type type) {
        updatePeer(fullJid, isa, type);
    }

    @Override
    public Peer addPeer(final URI fullJid, final Type type) {

        // This is a peer we know very little about at this point, as we
        // haven't made any network connections with them.
        final LanternRosterEntry entry = rosterEntry(fullJid);
        log.debug("Got roster entry: {} for '{}'", entry, fullJid);
        if (entry == null) {
            // This will happen for cloud "peers" and kscope peers but otherwise
            // all peers should be on your roster.
            log.debug("Could not find match for type '{}'", type);
            log.debug("Roster is: {}", this.roster.getEntries());
        }

        final Peer existing = this.model.getPeerCollector().getPeer(fullJid);

        if (existing != null) {
            log.debug("Peer already exists...");
            return existing;
        } else {
            log.debug("Adding peer {}", fullJid);
            final Peer peer = new Peer(fullJid, "", false, 0L, 0L, type,
                    "", 0, Mode.unknown, false, entry);
            this.model.getPeerCollector().addPeer(fullJid, peer);
            return peer;
        }
    }
    
    @Override
    public Peer peerForJid(URI fullJid) {
        return this.model.getPeerCollector().getPeer(fullJid);
    }
    
    private LanternRosterEntry rosterEntry(final URI fullJid) {
        return this.roster.getRosterEntry(fullJid.toASCIIString());
    }

    private final Map<X509Certificate, Peer> certsToPeers =
            new ConcurrentHashMap<X509Certificate, Peer>();

    @Subscribe
    public void onCert(final PeerCertEvent event) {
        final Peer peer = this.model.getPeerCollector().getPeer(event.getJid());
        if (peer == null) {
            log.error("Got a cert for peer we don't know about? " +
                    "{} not found in {}", event.getJid(),
                    this.model.getPeerCollector().getPeers().keySet());
        } else {
            try {
                byte[] certificateBytes = event.getCert().getEncoded();
                X509Certificate certificate = X509Certificate
                        .getInstance(certificateBytes);
                certsToPeers.put(certificate, peer);
            } catch (CertificateException ce) {
                log.error("Unable to decode X509 certificate", ce);
            } catch (CertificateEncodingException cee) {
                log.error("Unable to encode X509 certificate", cee);
            }
        }
    }

    @Override
    public Peer peerForSession(SSLSession sslSession) {
        try {
            X509Certificate[] certificateChain = sslSession
                    .getPeerCertificateChain();
            if (certificateChain.length == 0) {
                log.error("No certificates in chain");
                return null;
            }
            X509Certificate cert = certificateChain[0];
            return certsToPeers.get(cert);
        } catch (SSLPeerUnverifiedException spue) {
            log.debug("Peer not verified");
            return null;
        }
    }

    public void peerSentRequest(InetSocketAddress peerAddress,
            SSLSession sslSession) {
        Peer peer = peerForSession(sslSession);
        if (peer != null) {
            log.debug("Found peer by certificate!!!");
            peer.setMode(Mode.get);
            updatePeer(peer, peerAddress, Type.pc);
        } else {
            log.error("No peer found for ssl session: {}", sslSession);
        }
    }
}
