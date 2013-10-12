package org.lantern.kscope;

import java.net.InetSocketAddress;
import java.net.URI;
import java.net.URISyntaxException;
import java.security.cert.CertificateException;

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
import org.lantern.network.InstanceId;
import org.lantern.network.InstanceInfo;
import org.lantern.network.InstanceInfoWithCert;
import org.lantern.network.NetworkTracker;
import org.lantern.network.TrustedOnlineInstanceListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class DefaultKscopeAdHandler implements KscopeAdHandler,
        TrustedOnlineInstanceListener<String, URI, ReceivedKScopeAd> {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final XmppHandler xmppHandler;

    private final ProxyTracker proxyTracker;
    private final LanternTrustStore trustStore;
    private final RandomRoutingTable routingTable;
    private final NetworkTracker<String, URI, ReceivedKScopeAd> networkTracker;

    @Inject
    public DefaultKscopeAdHandler(
            final ProxyTracker proxyTracker,
            final LanternTrustStore trustStore,
            final RandomRoutingTable routingTable,
            final XmppHandler xmppHandler,
            final NetworkTracker<String, URI, ReceivedKScopeAd> networkTracker) {
        this.proxyTracker = proxyTracker;
        this.trustStore = trustStore;
        this.routingTable = routingTable;
        this.xmppHandler = xmppHandler;
        this.networkTracker = networkTracker;

        this.networkTracker.addTrustedOnlineInstanceListener(this);
    }

    @Override
    public void handleAd(final String from,
            final LanternKscopeAdvertisement ad) {
        // output a bell character to call more attention
        log.debug("\u0007*** got kscope ad from {} for {}", from, ad.getJid());
        Events.asyncEventBus().post(new KscopeAdEvent(ad));
        try {
            URI jid = new URI(from);
            InstanceId<String, URI> instanceId = LanternUtils
                    .instanceIdFor(jid);
            networkTracker
                    .instanceOnline(
                            instanceId,
                            new InstanceInfo<String, URI, ReceivedKScopeAd>(
                                    instanceId,
                                    new InetSocketAddress(ad.getLocalAddress(),
                                            ad.getLocalPort()),
                                    new InetSocketAddress(ad.getAddress(), ad
                                            .getPort()),
                                    new ReceivedKScopeAd(from, ad)));
        } catch (final URISyntaxException e) {
            log.error("Could not create URI from: {}", from);
        }
    }

    @Override
    public void onBase64Cert(final URI jid, final String base64Cert) {
        log.debug("Received cert for {}", jid);
        InstanceId<String, URI> instanceId = LanternUtils.instanceIdFor(jid);
        try {
            networkTracker.certificateReceived(instanceId,
                    LanternUtils.certFromBase64(base64Cert));
        } catch (CertificateException ce) {
            log.error("Unable to decode base64 cert: {}", base64Cert, ce);
        }
    }

    @Override
    public void instanceOnlineAndTrusted(
            InstanceInfoWithCert<String, URI, ReceivedKScopeAd> instance) {
        trustStore.addCert((URI) instance.getInstanceId().getFullId(),
                instance.getCertificate());
        addProxy(instance);
        relayKScopeAd(instance);
    }

    @Override
    public void instanceOfflineOrUntrusted(
            InstanceInfoWithCert<String, URI, ReceivedKScopeAd> instance) {
        // TODO Auto-generated method stub

    }

    private void relayKScopeAd(
            InstanceInfoWithCert<String, URI, ReceivedKScopeAd> instance) {
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

        final TrustGraphNode tgn =
                new LanternTrustGraphNode(xmppHandler);

        tgn.sendAdvertisement(message, nextNid, relayAd.getTtl());
    }

    private void addProxy(
            InstanceInfoWithCert<String, URI, ReceivedKScopeAd> instance) {
        log.debug("Adding proxy... {}", instance);
        URI jid = instance.getInstanceId().getFullId();
        InetSocketAddress address = instance.hasMappedEndpoint() ?
                instance.getAddressOnWan() :
                null;
        this.proxyTracker.addProxy(jid, address);
        // Also add the local network advertisement in case they're on
        // the local network.
        this.proxyTracker.addProxy(jid, instance.getAddressOnLan());
    }

}
