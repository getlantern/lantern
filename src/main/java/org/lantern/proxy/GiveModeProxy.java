package org.lantern.proxy;

import io.netty.handler.codec.http.HttpRequest;

import java.net.InetSocketAddress;

import javax.net.ssl.SSLSession;

import org.lantern.ClientStats;
import org.lantern.PeerFactory;
import org.lantern.state.Model;
import org.lantern.state.Peer;
import org.littleshoot.proxy.ActivityTrackerAdapter;
import org.littleshoot.proxy.FlowContext;
import org.littleshoot.proxy.FullFlowContext;
import org.littleshoot.proxy.HttpFilters;
import org.littleshoot.proxy.HttpFiltersSourceAdapter;
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
            final Model model,
            final SSLEngineSource sslEngineSource,
            final PeerFactory peerFactory) {
        super(DefaultHttpProxyServer
                .bootstrap()
                .withName("GiveModeProxy")
                .withPort(model.getSettings().getServerPort())
                .withAllowLocalOnly(false)
                .withListenOnAllAddresses(false)
                // TODO: need to use a different SSLEngineSource if we're a
                // fallback proxy since we want to allow anyone to connect
                .withSSLEngineSource(sslEngineSource)

                // Use a filter to deny requests to non-public ips
                .withFiltersSource(new HttpFiltersSourceAdapter() {
                    @Override
                    public HttpFilters filterRequest(HttpRequest originalRequest) {
                        return new GiveModeHttpFilters(originalRequest);
                    }
                })

                // Keep stats up to date
                .plusActivityTracker(new ActivityTrackerAdapter() {
                    @Override
                    public void bytesReceivedFromClient(
                            FlowContext flowContext,
                            int numberOfBytes) {
                        stats.addDownBytesFromPeers(numberOfBytes);
                        Peer peer = peerFor(flowContext);
                        if (peer != null) {
                            peer.addBytesDn(numberOfBytes);
                        }
                    }

                    @Override
                    public void bytesSentToServer(FullFlowContext flowContext,
                            int numberOfBytes) {
                        stats.addUpBytesForPeers(numberOfBytes);
                    }

                    @Override
                    public void bytesReceivedFromServer(
                            FullFlowContext flowContext,
                            int numberOfBytes) {
                        stats.addDownBytesForPeers(numberOfBytes);
                    }

                    @Override
                    public void bytesSentToClient(FlowContext flowContext,
                            int numberOfBytes) {
                        stats.addUpBytesToPeers(numberOfBytes);
                        Peer peer = peerFor(flowContext);
                        if (peer != null) {
                            peer.addBytesUp(numberOfBytes);
                        }
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

                    @Override
                    public void clientSSLHandshakeSucceeded(
                            InetSocketAddress clientAddress,
                            SSLSession sslSession) {
                        Peer peer = peerFor(sslSession);
                        if (peer != null) {
                            peer.connected();
                        }
                    }

                    private Peer peerFor(FlowContext flowContext) {
                        return peerFactory.peerForSession(flowContext
                                .getClientSSLSession());
                    }

                    private Peer peerFor(SSLSession sslSession) {
                        return peerFactory.peerForSession(sslSession);
                    }
                }));
    }
}
