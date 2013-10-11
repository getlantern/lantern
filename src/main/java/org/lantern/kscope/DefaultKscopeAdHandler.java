package org.lantern.kscope;

import java.net.InetSocketAddress;
import java.net.URI;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.kaleidoscope.BasicTrustGraphAdvertisement;
import org.kaleidoscope.BasicTrustGraphNodeId;
import org.kaleidoscope.RandomRoutingTable;
import org.kaleidoscope.TrustGraphNode;
import org.kaleidoscope.TrustGraphNodeId;
import org.lantern.JsonUtils;
import org.lantern.LanternTrustStore;
import org.lantern.LanternUtils;
import org.lantern.ProxyTracker;
import org.lantern.XmppHandler;
import org.lantern.event.Events;
import org.lantern.event.KscopeAdEvent;
import org.lantern.state.FriendsHandler;
import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class DefaultKscopeAdHandler implements KscopeAdHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final XmppHandler xmppHandler;
    
    /**
     * Map of kscope advertisements for which we are awaiting corresponding
     * certificates.
     */
    private final ConcurrentHashMap<URI, LanternKscopeAdvertisement> awaitingCerts = 
        new ConcurrentHashMap<URI, LanternKscopeAdvertisement>();
    
    private final Set<LanternKscopeAdvertisement> processedAds =
            new HashSet<LanternKscopeAdvertisement>();
    private final ProxyTracker proxyTracker;
    private final LanternTrustStore trustStore;
    private final RandomRoutingTable routingTable;
    private final Model model;
    private final FriendsHandler friendsHandler;
    
    @Inject
    public DefaultKscopeAdHandler(final ProxyTracker proxyTracker,
        final LanternTrustStore trustStore,
        final RandomRoutingTable routingTable,
        final XmppHandler xmppHandler, final Model model,
        final FriendsHandler friendsHandler) {
        this.proxyTracker = proxyTracker;
        this.trustStore = trustStore;
        this.routingTable = routingTable;
        this.xmppHandler = xmppHandler;
        this.model = model;
        this.friendsHandler = friendsHandler;
    }

    @Override
    public boolean handleAd(final String from,
            final LanternKscopeAdvertisement ad) {
        // output a bell character to call more attention
        log.debug("\u0007*** got kscope ad from {} for {}", from, ad.getJid());
        Events.asyncEventBus().post(new KscopeAdEvent(ad));

        //ignore kscope ads directly or indirectly from untrusted sources
        //(they might have been relayed via untrusted sources in the middle,
        //but there is nothing we can do about that)

        if (!this.friendsHandler.isFriend(ad.getJid())) {
            log.debug("Ignoring kscope add from non-friend");
            return false;
        }

        // If the connection we received the kscope add on is rejected, ignore
        // the add.
        if (this.friendsHandler.isRejected(from)) {
            log.debug("Ignoring kscope add from rejected contact");
            return false;
        }

        final LanternKscopeAdvertisement existing =
                awaitingCerts.put(LanternUtils.newURI(ad.getJid()), ad);
        if (existing != null) {
            if (existing.equals(ad)) {
                log.debug("Ignoring identical kscope ad - already processed");
                return false;
            }
        }
        // do we want to relay this?
        int inboundTtl = ad.getTtl();
        if(inboundTtl <= 0) {
            log.debug("End of the line for kscope ad for {} from {}.", 
                ad.getJid(), from
            );
            return true;
        }
        TrustGraphNodeId nid = new BasicTrustGraphNodeId(ad.getJid());
        TrustGraphNodeId nextNid = routingTable.getNextHop(nid);
        if (nextNid == null) {
            // This will happen when we're not connected to any other peers,
            // for example.
            log.debug("Could not relay ad: Node ID not in routing table");
            return true;
        }
        LanternKscopeAdvertisement relayAd = 
            LanternKscopeAdvertisement.makeRelayAd(ad);

        final String relayAdPayload = JsonUtils.jsonify(relayAd);
        final BasicTrustGraphAdvertisement message =
            new BasicTrustGraphAdvertisement(nextNid, relayAdPayload, 
                relayAd.getTtl()
            );

        final TrustGraphNode tgn = 
            new LanternTrustGraphNode(xmppHandler);
        
        tgn.sendAdvertisement(message, nextNid, relayAd.getTtl()); 
        return true;
    }

    @Override
    public void onBase64Cert(final URI jid, final String base64Cert) {
        log.debug("Received cert for {}", jid);
        this.trustStore.addBase64Cert(jid, base64Cert);
        
        final LanternKscopeAdvertisement ad = awaitingCerts.remove(jid);
        if (ad != null) {
            log.debug("Adding proxy... {}", ad);
            InetSocketAddress address = ad.hasMappedEndpoint() ?
                    LanternUtils.isa(ad.getAddress(), ad.getPort()) :
                    null;
            this.proxyTracker.addProxy(jid, address);
            // Also add the local network advertisement in case they're on
            // the local network.
            this.proxyTracker.addProxy(jid, 
                LanternUtils.isa(ad.getLocalAddress(), ad.getLocalPort()));
            processedAds.add(ad);
        } else {
            this.proxyTracker.addProxy(jid);
        }
    }

}
