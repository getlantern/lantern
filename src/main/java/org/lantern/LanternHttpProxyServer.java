package org.lantern;

import static org.jboss.netty.channel.Channels.pipeline;

import java.lang.Thread.UncaughtExceptionHandler;
import java.net.InetSocketAddress;
import java.util.Iterator;
import java.util.concurrent.atomic.AtomicBoolean;

import org.jboss.netty.bootstrap.ServerBootstrap;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.group.ChannelGroupFuture;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.ServerSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpRequestDecoder;
import org.jboss.netty.util.Timer;
import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * HTTP proxy server for local requests from the browser to Lantern.
 */
@Singleton
public class LanternHttpProxyServer implements HttpProxyServer {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final ChannelGroup channelGroup;
            
    private final int httpLocalPort = LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;

    //private final SetCookieObserver setCookieObserver;
    //private final CookieFilter.Factory cookieFilterFactory;

    private final ServerSocketChannelFactory serverChannelFactory;

    private final ClientSocketChannelFactory clientChannelFactory;

    private final Timer timer;

    private final XmppHandler xmppHandler;
    
    private final TrustedPeerProxyManager trustedPeerProxyManager;

    private final AnonymousPeerProxyManager anonymousPeerProxyManager;

    private final Stats stats;

    private final LanternKeyStoreManager keyStoreManager;

    private final Model model;

    /**
     * Creates a new proxy server.
     * 
     * @param httpLocalPort The port the HTTP server should run on.
     * @param clientChannelFactory The factory for creating outgoing client
     * connections.
     * @param timer The idle timeout timer. 
     * @param serverChannelFactory The factory for creating listening channels.
     * @param channelGroup The group of all channels for convenient closing.
     */
    @Inject
    public LanternHttpProxyServer(//final int httpLocalPort, 
        //final SetCookieObserver setCookieObserver, 
        //final CookieFilter.Factory cookieFilterFactory, 
        final ServerSocketChannelFactory serverChannelFactory, 
        final ClientSocketChannelFactory clientChannelFactory, 
        final Timer timer, final ChannelGroup channelGroup,
        final XmppHandler xmppHandler,
        final TrustedPeerProxyManager trustedPeerProxyManager,
        final AnonymousPeerProxyManager anonymousPeerProxyManager,
        final Stats stats,
        final LanternKeyStoreManager keyStoreManager,
        final Model model) {
        this.trustedPeerProxyManager = trustedPeerProxyManager;
        this.anonymousPeerProxyManager = anonymousPeerProxyManager;
        //this.setCookieObserver = setCookieObserver;
        //this.cookieFilterFactory = cookieFilterFactory;
        this.serverChannelFactory = serverChannelFactory;
        this.clientChannelFactory = clientChannelFactory;
        this.timer = timer;
        this.channelGroup = channelGroup;
        this.xmppHandler = xmppHandler;
        this.stats = stats;
        this.keyStoreManager = keyStoreManager;
        this.model = model;

        Thread.setDefaultUncaughtExceptionHandler(new UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(final Thread t, final Throwable e) {
                log.error("Uncaught exception", e);
            }
        });    
    }


    @Override
    public void start() {
        log.info("Starting proxy on HTTP port "+httpLocalPort);
        
        newServerBootstrap(newHttpChannelPipelineFactory(), 
            httpLocalPort);
        log.info("Built HTTP server");
        
        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
            @Override
            public void run() {
                stop();
            }
        }, "LanternHttpProxyServer-Shutdown-Thread"));
        /*
        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
            public void run() {
                log.info("Got shutdown hook...closing all channels.");
                final ChannelGroupFuture future = allChannels.close();
                try {
                    future.await(6*1000);
                } catch (final InterruptedException e) {
                    log.info("Interrupted", e);
                }
                bootstrap.releaseExternalResources();
                log.info("Closed all channels...");
            }
        }));
        */
    }
    

    @Override
    public void start(final boolean localOnly, final boolean anyAddress) {
        start();
    }
    
    private ServerBootstrap newServerBootstrap(
        final ChannelPipelineFactory pipelineFactory, final int port) {
        final ServerBootstrap bootstrap = 
            new ServerBootstrap(this.serverChannelFactory);

        bootstrap.setPipelineFactory(pipelineFactory);
        
        // We always only bind to localhost here for better security.
        final Channel channel = 
            bootstrap.bind(new InetSocketAddress("127.0.0.1", port));
        channelGroup.add(channel);
        
        return bootstrap;
    }

    private ChannelPipelineFactory newHttpChannelPipelineFactory() {
        return new ChannelPipelineFactory() {
            @Override
            public ChannelPipeline getPipeline() throws Exception {
                
                final SimpleChannelUpstreamHandler dispatcher = 
                    new DispatchingProxyRelayHandler(clientChannelFactory, 
                        channelGroup, xmppHandler, trustedPeerProxyManager,
                        anonymousPeerProxyManager, stats, keyStoreManager, 
                        model);
                
                final ChannelPipeline pipeline = pipeline();
                pipeline.addLast("decoder", 
                    new HttpRequestDecoder(8192, 8192*2, 8192*2));
                pipeline.addLast("encoder", 
                    new LanternHttpResponseEncoder(stats));
                
                /*
                if (setCookieObserver != null) {
                    final ChannelHandler watchCookies = 
                        new SetCookieObserverHandler(setCookieObserver);
                    pipeline.addLast("setCookieObserver", watchCookies);
                }
                
                if (cookieFilterFactory != null) {
                    final ChannelHandler filterCookies =
                        new UpstreamCookieFilterHandler(cookieFilterFactory);
                    pipeline.addLast("cookieFilter", filterCookies);
                }
                */

                pipeline.addLast("handler", dispatcher);

                return pipeline;
            }
        };
    }

    private final AtomicBoolean stopped = new AtomicBoolean(false);
    
    @Override
    public void stop() {
        log.info("Shutting down proxy");
        if (stopped.get()) {
            log.info("Already stopped");
            return;
        }
        stopped.set(true);
        
        log.info("Closing all channels...");
        
        // See http://static.netty.io/3.5/guide/#start.12
        final ChannelGroupFuture future = channelGroup.close();
        future.awaitUninterruptibly(10*1000);
        
        if (!future.isCompleteSuccess()) {
            final Iterator<ChannelFuture> iter = future.iterator();
            while (iter.hasNext()) {
                final ChannelFuture cf = iter.next();
                if (!cf.isSuccess()) {
                    log.warn("Cause of failure for {} is {}", cf.getChannel(), cf.getCause());
                }
            }
        }
        log.info("Stopping timer");
        timer.stop();
        
        log.info("Releasing server channel external resources...");
        serverChannelFactory.releaseExternalResources();
        log.info("Releasing client channel external resources...");
        clientChannelFactory.releaseExternalResources();
        log.info("Done shutting down proxy");
    }

}
