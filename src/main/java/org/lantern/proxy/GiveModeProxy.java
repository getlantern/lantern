package org.lantern.proxy;

import java.net.InetSocketAddress;

import javax.net.ssl.SSLPeerUnverifiedException;
import javax.net.ssl.SSLSession;

import org.lantern.ClientStats;
import org.lantern.event.Events;
import org.lantern.event.IncomingPeerEvent;
import org.lantern.state.Model;
import org.littleshoot.proxy.ActivityTrackerAdapter;
import org.littleshoot.proxy.FlowContext;
import org.littleshoot.proxy.FullFlowContext;
import org.littleshoot.proxy.SSLEngineSource;
import org.littleshoot.proxy.impl.DefaultHttpProxyServer;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * HTTP proxy server for remote requests to Lantern (i.e. in Give Mode).
 */
@Singleton
public class GiveModeProxy extends AbstractHttpProxyServerAdapter {
    @Inject
    public GiveModeProxy(
            final ClientStats stats,
            Model model,
            SSLEngineSource sslEngineSource) {
        super(DefaultHttpProxyServer
                .bootstrap()
                .withName("GiveModeProxy")
                .withPort(model.getSettings().getServerPort())
                .withSSLEngineSource(sslEngineSource));

        // Keep ClientStats up to date using an ActivityTracker
        server.addActivityTracker(new ActivityTrackerAdapter() {
            @Override
            public void bytesReceivedFromClient(FlowContext flowContext,
                    int numberOfBytes) {
                stats.addDownBytesFromPeers(numberOfBytes);
            }

            @Override
            public void bytesSentToServer(FullFlowContext flowContext,
                    int numberOfBytes) {
                stats.addUpBytesForPeers(numberOfBytes);
            }

            @Override
            public void bytesReceivedFromServer(FullFlowContext flowContext,
                    int numberOfBytes) {
                stats.addDownBytesForPeers(numberOfBytes);
            }

            @Override
            public void bytesSentToClient(FlowContext flowContext,
                    int numberOfBytes) {
                stats.addUpBytesToPeers(numberOfBytes);
            }

            @Override
            public void clientSSLHandshakeSucceeded(
                    InetSocketAddress clientAddress, SSLSession sslSession) {
                try {
                    Events.asyncEventBus().post(
                            new IncomingPeerEvent(clientAddress, sslSession
                                    .getPeerCertificateChain()[0]));
                } catch (SSLPeerUnverifiedException pue) {
                    throw new Error(
                            "If the SSL handshake succeeded, the peer should already be verified");
                }
            }
        });
    }
}
