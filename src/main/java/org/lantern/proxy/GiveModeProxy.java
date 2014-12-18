package org.lantern.proxy;

import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.http.HttpRequest;

import java.net.InetSocketAddress;

import org.lantern.LanternUtils;
import org.lantern.PeerFactory;
import org.lantern.event.Events;
import org.lantern.event.ModeChangedEvent;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.proxy.pt.PluggableTransport;
import org.lantern.proxy.pt.PluggableTransports;
import org.lantern.state.InstanceStats;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.state.Settings;
import org.littleshoot.proxy.HttpFilters;
import org.littleshoot.proxy.HttpFiltersSourceAdapter;
import org.littleshoot.proxy.HttpProxyServerBootstrap;
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
            final Model model,
            final SslEngineSource sslEngineSource,
            final PeerFactory peerFactory,
            final GeoIpLookupService lookupService) {
        final InstanceStats stats = model.getInstanceStats();
        final Settings settings = model.getSettings();
        int serverPort = settings.getServerPort();
        boolean allowLocalOnly = false;
        boolean encryptionRequired = true;
        if (settings.getProxyPtType() != null) {
            // When using a pluggable transport, the transport will use the
            // configured port and the server will use some random free port
            // that only allows local connections
            serverPort = LanternUtils.findFreePort();
            allowLocalOnly = true;
            pluggableTransport =
                    PluggableTransports.newTransport(
                            settings.getProxyPtType(),
                            settings.getProxyPtProps());
            encryptionRequired = !pluggableTransport.suppliesEncryption();
            log.info("GiveModeProxy will use pluggable transport of type: "
                    + pluggableTransport.getClass().getName());
        }

        HttpProxyServerBootstrap bootstrap =
                DefaultHttpProxyServer
                        .bootstrap()
                        .withName("GiveModeProxy")
                        .withPort(serverPort)
                        .withTransportProtocol(settings.getProxyProtocol())
                        .withAllowLocalOnly(allowLocalOnly)
                        .withListenOnAllAddresses(false)

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
                        .plusActivityTracker(
                                new GiveModeActivityTracker(stats,
                                        lookupService, peerFactory));
        if (encryptionRequired) {
            bootstrap
                    .withSslEngineSource(sslEngineSource)
                    .withAuthenticateSslClients(!LanternUtils.isFallbackProxy());
        }
        setBootstrap(bootstrap);

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
            log.info("Starting PluggableTransport");
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
