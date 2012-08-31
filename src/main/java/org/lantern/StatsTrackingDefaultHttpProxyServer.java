package org.lantern; 

import java.lang.Thread.UncaughtExceptionHandler;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;
import java.util.Map;

import org.jboss.netty.bootstrap.ServerBootstrap;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFactory;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.group.ChannelGroupFuture;
import org.jboss.netty.channel.group.DefaultChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.ServerSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.util.Timer;
import org.littleshoot.proxy.ChainProxyManager;
import org.littleshoot.proxy.DefaultProxyAuthorizationManager;
import org.littleshoot.proxy.DefaultRelayPipelineFactoryFactory;
import org.littleshoot.proxy.HttpFilter;
import org.littleshoot.proxy.HttpRequestFilter;
import org.littleshoot.proxy.HttpResponseFilters;
import org.littleshoot.proxy.HttpServerPipelineFactory;
import org.littleshoot.proxy.NetworkUtils;
import org.littleshoot.proxy.ProxyAuthorizationHandler;
import org.littleshoot.proxy.ProxyAuthorizationManager;
import org.littleshoot.proxy.RelayListener;
import org.littleshoot.proxy.RelayPipelineFactoryFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * This is a the little proxy DefaultHttpProxyServer slightly
 * hacked up to track some extra lantern statistics.
 *
 * DefaultHttpProxyServer is severely unfriendly to subclassing
 * so it is cargo culted in full with specific additions.
 *
 */
public class StatsTrackingDefaultHttpProxyServer implements HttpProxyServer {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final ChannelGroup allChannels =
        new DefaultChannelGroup("HTTP-Proxy-Server");

    private final int port;

    private final ProxyAuthorizationManager authenticationManager =
        new DefaultProxyAuthorizationManager();

    private final ChainProxyManager chainProxyManager;

    private final HttpRequestFilter requestFilter;

    private final ServerBootstrap serverBootstrap;

    private final HttpResponseFilters responseFilters;

    private ChannelFactory serverChannelFactory;

    private Timer timer;

    private ClientSocketChannelFactory clientChannelFactory;

    /**
     * Creates a new proxy server.
     *
     * @param port The port the server should run on.
     */
    /*
    public StatsTrackingDefaultHttpProxyServer(final int port) {
        this(port, new HttpResponseFilters() {
            public HttpFilter getFilter(String hostAndPort) {
                return null;
            }
        });
    }
    */

    /**
     * Creates a new proxy server.
     *
     * @param port The port the server should run on.
     * @param responseFilters The {@link Map} of request domains to match
     * with associated {@link HttpFilter}s for filtering responses to
     * those requests.
     */
    /*
    public StatsTrackingDefaultHttpProxyServer(final int port,
        final HttpResponseFilters responseFilters) {
        this(port, responseFilters, null, null);
    }
    */

    /**
     * Creates a new proxy server.
     *
     * @param port The port the server should run on.
     * @param requestFilter The filter for HTTP requests.
     * @param responseFilters HTTP filters to apply.
     */
    /*
    public StatsTrackingDefaultHttpProxyServer(final int port,
        final HttpRequestFilter requestFilter,
        final HttpResponseFilters responseFilters) {
        this(port, responseFilters, null, requestFilter);
    }
    */

    /**
     * Creates a new proxy server.
     *
     * @param port The port the server should run on.
     * @param responseFilters The {@link Map} of request domains to match
     * with associated {@link HttpFilter}s for filtering responses to
     * those requests.
     * @param chainProxyManager The proxy to send requests to if chaining
     * proxies. Typically <code>null</code>.
     * @param ksm The key manager if running the proxy over SSL.
     * @param requestFilter Optional filter for modifying incoming requests.
     * Often <code>null</code>.
     * @param clientChannelFactory The factory for creating outgoing client
     * connections.
     * @param timer The idle timeout timer. 
     * @param serverChannelFactory The factory for creating listening channels.
     */
    public StatsTrackingDefaultHttpProxyServer(final int port,
        final HttpResponseFilters responseFilters,
        final ChainProxyManager chainProxyManager,
        final HttpRequestFilter requestFilter, 
        final ClientSocketChannelFactory clientChannelFactory, 
        final Timer timer,
        final ServerSocketChannelFactory serverChannelFactory) {
        this.port = port;
        this.responseFilters = responseFilters;
        this.requestFilter = requestFilter;
        this.chainProxyManager = chainProxyManager;
        this.clientChannelFactory = clientChannelFactory;
        this.timer = timer;
        this.serverChannelFactory = serverChannelFactory;
        Thread.setDefaultUncaughtExceptionHandler(new UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(final Thread t, final Throwable e) {
                log.error("Uncaught throwable", e);
            }
        });

        this.serverBootstrap = new ServerBootstrap(this.serverChannelFactory);
    }

    @Override
    public void start() {
        start(false, true);
    }

    public void start(final boolean localOnly, final boolean anyAddress) {
        log.info("Starting proxy on port: "+this.port);
        final HttpServerPipelineFactory factory =
            new StatsTrackingHttpServerPipelineFactory(authenticationManager,
                this.allChannels, this.chainProxyManager, 
                new StatsTrackingDefaultRelayPipelineFactoryFactory(chainProxyManager,
                    this.responseFilters, this.requestFilter,
                    this.allChannels, this.timer), this.clientChannelFactory, 
                    this.timer);
        serverBootstrap.setPipelineFactory(factory);

        // Binding only to localhost can significantly improve the security of
        // the proxy.
        InetSocketAddress isa;
        if (localOnly) {
            isa = new InetSocketAddress("127.0.0.1", port);
        }
        else if (anyAddress) {
            isa = new InetSocketAddress(port);
        } else {
            try {
                isa = new InetSocketAddress(NetworkUtils.getLocalHost(), port);
            } catch (final UnknownHostException e) {
                log.error("Could not get local host?", e);
                isa = new InetSocketAddress(port);
            }
        }
        final Channel channel = serverBootstrap.bind(isa);
        allChannels.add(channel);

        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
            @Override
            public void run() {
                stop();
            }
        }));
    }

    public void stop() {
        //log.info("Shutting down proxy");
        //final ChannelGroupFuture future = allChannels.close();
        //future.awaitUninterruptibly(6*1000);
        //serverBootstrap.releaseExternalResources();
        //log.info("Done shutting down proxy");
    }

    public void addProxyAuthenticationHandler(
        final ProxyAuthorizationHandler pah) {
        this.authenticationManager.addHandler(pah);
    }
    
    private static class StatsTrackingHttpServerPipelineFactory 
        extends HttpServerPipelineFactory {
        
        public StatsTrackingHttpServerPipelineFactory(
            final ProxyAuthorizationManager authorizationManager, 
            final ChannelGroup channelGroup, 
            final ChainProxyManager chainProxyManager, 
            final RelayPipelineFactoryFactory relayPipelineFactoryFactory,
            final ClientSocketChannelFactory clientChannelFactory, 
            final Timer timer) {
            super(authorizationManager, channelGroup, chainProxyManager, 
                LanternHub.getKeyStoreManager(), relayPipelineFactoryFactory, 
                timer, clientChannelFactory);
        }

        @Override
        public ChannelPipeline getPipeline() throws Exception {
            ChannelPipeline pipeline = super.getPipeline();
            pipeline.addFirst("stats", new StatsTrackingHandler() {
                public void addUpBytes(long bytes, Channel channel) {
                    statsTracker().addUpBytesToPeers(bytes, channel);
                }
                public void addDownBytes(long bytes, Channel channel) {
                    statsTracker().addDownBytesFromPeers(bytes, channel);
                }
            });
            return pipeline;
        }
    }
    
    private static class StatsTrackingDefaultRelayPipelineFactoryFactory 
        extends DefaultRelayPipelineFactoryFactory {
        
        public StatsTrackingDefaultRelayPipelineFactoryFactory(
            final ChainProxyManager chainProxyManager, 
            final HttpResponseFilters responseFilters, 
            final HttpRequestFilter requestFilter, 
            final ChannelGroup channelGroup,
            final Timer timer) {
            super(chainProxyManager, responseFilters, requestFilter, channelGroup, timer);
        }
        
        @Override
        public ChannelPipelineFactory getRelayPipelineFactory(
            final HttpRequest httpRequest,final Channel browserToProxyChannel,
            final RelayListener relayListener) {
            final ChannelPipelineFactory innerFactory =
                    super.getRelayPipelineFactory(httpRequest, browserToProxyChannel, relayListener);

            return new ChannelPipelineFactory() {
                @Override
                public ChannelPipeline getPipeline() throws Exception {
                    ChannelPipeline pipeline = innerFactory.getPipeline();
                    pipeline.addFirst("stats", new StatsTrackingHandler() {
                        @Override
                        public void addUpBytes(final long bytes, final Channel channel) {
                            statsTracker().addUpBytesForPeers(bytes, browserToProxyChannel);
                        }
                        @Override
                        public void addDownBytes(final long bytes, final Channel channel) {
                            statsTracker().addDownBytesForPeers(bytes, browserToProxyChannel);
                        }
                    });
                    return pipeline;
                }
            };
        }
    }

}


