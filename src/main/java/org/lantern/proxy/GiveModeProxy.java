package org.lantern.proxy;

import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.http.HttpRequest;

import java.net.InetSocketAddress;
import java.util.HashMap;

import javax.net.ssl.SSLSession;

import org.lantern.ClientStats;
import org.lantern.LanternUtils;
import org.lantern.PeerFactory;
import org.lantern.event.Events;
import org.lantern.event.ModeChangedEvent;
import org.lantern.proxy.pt.PluggableTransport;
import org.lantern.proxy.pt.PluggableTransports;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.state.Peer;
import org.lantern.state.Settings;
import org.littleshoot.proxy.ActivityTrackerAdapter;
import org.littleshoot.proxy.FlowContext;
import org.littleshoot.proxy.FullFlowContext;
import org.littleshoot.proxy.HttpFilters;
import org.littleshoot.proxy.HttpFiltersSourceAdapter;
import org.littleshoot.proxy.SslEngineSource;
import org.littleshoot.proxy.TransportProtocol;
import org.littleshoot.proxy.impl.DefaultHttpProxyServer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * <p>
 * HTTP proxy server for remote requests to Lantern (i.e. in Give Mode).
 * </p>
 * 
 * <p>
 * GiveModeProxy starts and stops itself based on {@link ModeChangedEvent}s so
 * that it's only running when Lantern is in Give mode.
 * </p>
 */
@Singleton
public class GiveModeProxy extends AbstractHttpProxyServerAdapter {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private Model model;
    private volatile boolean running = false;
    private PluggableTransport pluggableTransport;

    @Inject
    public GiveModeProxy(
            final ClientStats stats,
            final Model model,
            final SslEngineSource sslEngineSource,
            final PeerFactory peerFactory) {
        final Settings settings = model.getSettings();
        int configuredPort = settings.getServerPort();
        int serverPort = configuredPort;
        boolean allowLocalOnly = false;
        if (settings.getProxyPtType() != null) {
            // When using a pluggable transport, the transport will use the
            // configured port and the server will use some random free port
            // that only allows local connections
            configuredPort = LanternUtils.findFreePort();
            allowLocalOnly = true;
            pluggableTransport =
                    PluggableTransports.newTransport(
                            settings.getProxyPtType(),
                            settings.getProxyPtProps());
            log.info("GiveModeProxy will use pluggable transport of type: "
                    + pluggableTransport.getClass().getName());
        }
        setBootstrap(DefaultHttpProxyServer
                .bootstrap()
                .withName("GiveModeProxy")
                .withPort(serverPort)
                .withTransportProtocol(settings.getProxyProtocol())
                .withAllowLocalOnly(allowLocalOnly)
                .withListenOnAllAddresses(false)
                .withSslEngineSource(sslEngineSource)
                .withAuthenticateSslClients(!LanternUtils.isFallbackProxy())

                // Use a filter to deny requests to non-public ips
                .withFiltersSource(new HttpFiltersSourceAdapter() {
                    @Override
                    public HttpFilters filterRequest(
                            HttpRequest originalRequest,
                            ChannelHandlerContext ctx) {
                        return new GiveModeHttpFilters(originalRequest,
                                ctx,
                                model.getReportIp(),
                                settings.getProxyPort(),
                                settings.getProxyProtocol(),
                                settings.getProxyAuthToken());
                    }
                })

                // Keep stats up to date
                .plusActivityTracker(new ActivityTrackerAdapter() {
                    @Override
                    public void bytesReceivedFromClient(
                            FlowContext flowContext,
                            int numberOfBytes) {
                        stats.addDownBytesFromPeers(numberOfBytes,
                                flowContext.getClientAddress().getAddress());
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
                        stats.addUpBytesToPeers(numberOfBytes,
                                flowContext.getClientAddress().getAddress());
                        Peer peer = peerFor(flowContext);
                        if (peer != null) {
                            peer.addBytesUp(numberOfBytes);
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
                        return peerFor(flowContext.getClientSslSession());
                    }

                    private Peer peerFor(SSLSession sslSession) {
                        return sslSession != null ? peerFactory
                                .peerForSession(sslSession) : null;
                    }
                }));
        this.model = model;
        Events.register(this);
        log.info(
                "Creating give mode proxy on port {}, running as fallback: {}",
                settings.getServerPort(),
                LanternUtils.isFallbackProxy());
    }

    @Override
    public synchronized void start() {
        super.start();

        if (TransportProtocol.TCP == model.getSettings().getProxyProtocol()) {
            InetSocketAddress original = server.getListenAddress();
            InetSocketAddress next = new InetSocketAddress(
                    original.getAddress(),
                    original.getPort() - 443);
            server.clone()
                    .withAddress(next)
                    .withSslEngineSource(null)
                    .start();
            log.info("Added additional unencrypted server for TCP on port {}",
                    next.getPort());
        }

        // Start the pluggable transport if necessary
        if (pluggableTransport != null) {
            int port = model.getSettings().getServerPort();
            InetSocketAddress giveModeAddress = server.getListenAddress();
            pluggableTransport.startServer(port, giveModeAddress);
        }

        running = true;
        log.info("Started GiveModeProxy");
    }

    @Override
    public synchronized void stop() {
        super.stop();
        running = false;

        // Stop the pluggable transport if necessary
        if (pluggableTransport != null) {
            pluggableTransport.stopServer();
        }

        log.info("Stopped GiveModeProxy");
    }

    @Subscribe
    public void modeChanged(ModeChangedEvent event) {
        log.debug("Got mode change");
        if (Mode.give == event.getNewMode()) {
            if (!running) {
                start();
            }
        } else {
            if (running) {
                stop();
            }
        }
    }

}
