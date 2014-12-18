package org.lantern.proxy;

import java.net.InetAddress;
import java.net.InetSocketAddress;

import javax.net.ssl.SSLSession;

import org.lantern.PeerFactory;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.state.InstanceStats;
import org.lantern.state.Peer;
import org.littleshoot.proxy.ActivityTracker;
import org.littleshoot.proxy.ActivityTrackerAdapter;
import org.littleshoot.proxy.FlowContext;
import org.littleshoot.proxy.FullFlowContext;

/**
 * {@link ActivityTracker} that tracks activity for a give mode proxy.
 */
public class GiveModeActivityTracker extends ActivityTrackerAdapter {
    private InstanceStats stats;
    protected GeoIpLookupService lookupService;
    private PeerFactory peerFactory;

    public GiveModeActivityTracker(InstanceStats stats,
            GeoIpLookupService lookupService, PeerFactory peerFactory) {
        super();
        this.stats = stats;
        this.lookupService = lookupService;
        this.peerFactory = peerFactory;
    }

    @Override
    public void bytesReceivedFromClient(
            FlowContext flowContext,
            int numberOfBytes) {
        InetAddress peerAddress = flowContext
                .getClientAddress().getAddress();
        stats.addBytesGivenForLocation(
                lookupService.getGeoData(peerAddress),
                numberOfBytes);
        Peer peer = peerFor(flowContext);
        if (peer != null) {
            peer.addBytesDn(numberOfBytes);
        }
        stats.addAllBytes(numberOfBytes);
    }

    @Override
    public void bytesSentToClient(
            FlowContext flowContext,
            int numberOfBytes) {
        InetAddress peerAddress = flowContext
                .getClientAddress().getAddress();
        stats.addBytesGivenForLocation(
                lookupService.getGeoData(peerAddress),
                numberOfBytes);
        Peer peer = peerFor(flowContext);
        if (peer != null) {
            peer.addBytesUp(numberOfBytes);
        }
        stats.addAllBytes(numberOfBytes);
    }

    @Override
    public void bytesSentToServer(
            FullFlowContext flowContext,
            int numberOfBytes) {
        stats.addAllBytes(numberOfBytes);
    }

    @Override
    public void bytesReceivedFromServer(
            FullFlowContext flowContext,
            int numberOfBytes) {
        stats.addAllBytes(numberOfBytes);
    }

    @Override
    public void clientSSLHandshakeSucceeded(
            InetSocketAddress clientAddress,
            SSLSession sslSession) {
        Peer peer = peerFor(sslSession);
        if (peer != null) {
            peer.connected();
        }
        stats.addProxiedClientAddress(clientAddress
                .getAddress());
    }

    @Override
    public void clientDisconnected(
            InetSocketAddress clientAddress,
            SSLSession sslSession) {
        Peer peer = peerFor(sslSession);
        if (peer != null) {
            peer.disconnected();
        }
    }

    private Peer peerFor(FlowContext flowContext) {
        return peerFor(flowContext
                .getClientSslSession());
    }

    private Peer peerFor(SSLSession sslSession) {
        if (peerFactory == null) {
            return null;
        }
        return sslSession != null ? peerFactory
                .peerForSession(sslSession) : null;
    }
}
