package org.lantern;

import static org.jboss.netty.channel.Channels.pipeline;

import java.lang.Thread.UncaughtExceptionHandler;
import java.net.InetSocketAddress;

import org.jboss.netty.bootstrap.ServerBootstrap;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandler;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.group.DefaultChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.ServerSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpRequestDecoder;
import org.jboss.netty.util.Timer;
import org.lantern.cookie.CookieFilter;
import org.lantern.cookie.SetCookieObserver;
import org.lantern.cookie.SetCookieObserverHandler;
import org.lantern.cookie.UpstreamCookieFilterHandler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * HTTP proxy server for local requests from the browser to Lantern.
 */
public class LanternHttpProxyServer implements HttpProxyServer {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final ChannelGroup channelGroup;
            
    private final int httpLocalPort;

    private final SetCookieObserver setCookieObserver;
    //private final CookieFilter.Factory cookieFilterFactory;

    private final ServerSocketChannelFactory serverChannelFactory;

    private final ClientSocketChannelFactory clientChannelFactory;

    private final Timer timer;

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
    public LanternHttpProxyServer(final int httpLocalPort, 
        final SetCookieObserver setCookieObserver, 
        final CookieFilter.Factory cookieFilterFactory, 
        final ServerSocketChannelFactory serverChannelFactory, 
        final ClientSocketChannelFactory clientChannelFactory, 
        final Timer timer, final ChannelGroup channelGroup) {
            
        this.httpLocalPort = httpLocalPort;
        this.setCookieObserver = setCookieObserver;
        //this.cookieFilterFactory = cookieFilterFactory;
        this.serverChannelFactory = serverChannelFactory;
        this.clientChannelFactory = clientChannelFactory;
        this.timer = timer;
        this.channelGroup = channelGroup;

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
                        channelGroup);
                
                final ChannelPipeline pipeline = pipeline();
                pipeline.addLast("decoder", 
                    new HttpRequestDecoder(8192, 8192*2, 8192*2));
                pipeline.addLast("encoder", 
                    new LanternHttpResponseEncoder(LanternHub.statsTracker()));
                
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
}
