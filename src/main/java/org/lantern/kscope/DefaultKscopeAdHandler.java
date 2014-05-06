package org.lantern.kscope;

import java.net.URI;
import java.net.URISyntaxException;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;

import org.kaleidoscope.BasicTrustGraphAdvertisement;
import org.kaleidoscope.BasicTrustGraphNodeId;
import org.kaleidoscope.RandomRoutingTable;
import org.kaleidoscope.TrustGraphNode;
import org.kaleidoscope.TrustGraphNodeId;
import org.lantern.JsonUtils;
import org.lantern.LanternTrustStore;
import org.lantern.LanternUtils;
import org.lantern.event.Events;
import org.lantern.event.KscopeAdEvent;
import org.lantern.network.InstanceInfo;
import org.lantern.network.NetworkTracker;
import org.lantern.network.NetworkTrackerListener;
import org.lantern.proxy.ProxyTracker;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class DefaultKscopeAdHandler implements KscopeAdHandler,
        NetworkTrackerListener<URI, ReceivedKScopeAd> {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final ProxyTracker proxyTracker;
    private final LanternTrustStore trustStore;
    private final RandomRoutingTable routingTable;
    private final NetworkTracker<String, URI, ReceivedKScopeAd> networkTracker;

    @Inject
    public DefaultKscopeAdHandler(
            final ProxyTracker proxyTracker,
            final LanternTrustStore trustStore,
            final RandomRoutingTable routingTable,
            final NetworkTracker<String, URI, ReceivedKScopeAd> networkTracker) {
        this.proxyTracker = proxyTracker;
        this.trustStore = trustStore;
        this.routingTable = routingTable;
        this.networkTracker = networkTracker;

        this.networkTracker.addListener(this);
    }

    @Override
    public boolean handleAd(final String from,
            final LanternKscopeAdvertisement ad) {
        // output a bell character to call more attention
        log.debug("\u0007*** got kscope ad from {} for {}", from, ad.getJid());
        Events.asyncEventBus().post(new KscopeAdEvent(ad));
        try {
            URI jid = new URI(from);
            String advertisingUser = XmppUtils.jidToUser(from);
            return networkTracker
                    .instanceOnline(
                            advertisingUser,
                            jid,
                            new InstanceInfo<URI, ReceivedKScopeAd>(
                                    jid,
                                    ad.getProxyInfo().lanAddress(),
                                    ad.getProxyInfo().wanAddress(),
                                    new ReceivedKScopeAd(from, ad)));
        } catch (final URISyntaxException e) {
            log.error("Could not create URI from: {}", from);
            return false;
        }
    }

    @Override
    public void onBase64Cert(final URI jid, final String base64Cert) {
        log.debug("Received cert for {}", jid);
        try {
            Certificate certificate = LanternUtils.certFromBase64(base64Cert);
            trustStore.addCert(jid, certificate);
            networkTracker.certificateTrusted(jid, certificate);
        } catch (CertificateException ce) {
            log.error("Unable to decode base64 cert: {}", base64Cert, ce);
        }
    }

    @Override
    public void instanceOnlineAndTrusted(
            InstanceInfo<URI, ReceivedKScopeAd> instance) {
        relayKScopeAd(instance);
    }

    @Override
    public void instanceOfflineOrUntrusted(
            InstanceInfo<URI, ReceivedKScopeAd> instance) {
        // TODO Auto-generated method stub

    }

    private void relayKScopeAd(
            InstanceInfo<URI, ReceivedKScopeAd> instance) {
        ReceivedKScopeAd receivedAd = instance.getData();
        LanternKscopeAdvertisement ad = receivedAd.getAd();
        Integer inboundTtl = ad.getTtl();
        // do we want to relay this?
        if (inboundTtl <= 0) {
            log.debug("End of the line for kscope ad for {} from {}.",
                    ad.getJid(), receivedAd.getFrom());
            return;
        }
        TrustGraphNodeId nid = new BasicTrustGraphNodeId(ad.getJid());
        TrustGraphNodeId nextNid = routingTable.getNextHop(nid);
        if (nextNid == null) {
            // This will happen when we're not connected to any other peers,
            // for example.
            log.debug("Could not relay ad: Node ID not in routing table");
            return;
        }
        LanternKscopeAdvertisement relayAd =
                LanternKscopeAdvertisement.makeRelayAd(ad);

        final String relayAdPayload = JsonUtils.jsonify(relayAd);
        final BasicTrustGraphAdvertisement message =
                new BasicTrustGraphAdvertisement(nextNid, relayAdPayload,
                        relayAd.getTtl()
                );

        final TrustGraphNode tgn = new LanternTrustGraphNode();

        tgn.sendAdvertisement(message, nextNid, relayAd.getTtl());
    }
}
