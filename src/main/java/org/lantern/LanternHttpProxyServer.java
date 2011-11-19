package org.lantern;

import static org.jboss.netty.channel.Channels.pipeline;

import java.lang.Thread.UncaughtExceptionHandler;
import java.net.InetSocketAddress;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;

import org.jboss.netty.bootstrap.ServerBootstrap;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.group.DefaultChannelGroup;
import org.jboss.netty.channel.socket.nio.NioServerSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpRequestDecoder;
import org.littleshoot.proxy.KeyStoreManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * HTTP proxy server for local requests from the browser to Lantern.
 */
public class LanternHttpProxyServer implements HttpProxyServer {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final ChannelGroup allChannels = 
        new DefaultChannelGroup("Local-HTTP-Proxy-Server");
            
    private final int httpLocalPort;

    private final KeyStoreManager keyStoreManager;

    private final int httpsLocalPort;

    //private final XmppHandler xmpp;
    
    /**
     * Creates a new proxy server.
     * 
     * @param httpLocalPort The port the HTTP server should run on.
     * @param httpsLocalPort The port the HTTPS server should run on.
     * @param filters HTTP filters to apply.
     * @param xmpp The class dealing with all XMPP interaction with the server.
     */
    public LanternHttpProxyServer(final int httpLocalPort, 
        final int httpsLocalPort, final KeyStoreManager keyStoreManager, 
        final XmppHandler xmpp) {
        this.httpLocalPort = httpLocalPort;
        this.httpsLocalPort = httpsLocalPort;
        this.keyStoreManager = keyStoreManager;
        //this.xmpp = xmpp;
        Thread.setDefaultUncaughtExceptionHandler(new UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(final Thread t, final Throwable e) {
                log.error("Uncaught exception", e);
            }
        });
    }
    

    @Override
    public void start() {
        log.info("Starting proxy on HTTP port "+httpLocalPort+
            " and HTTPS port "+httpsLocalPort);
        
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
        final ServerBootstrap bootstrap = new ServerBootstrap(
            new NioServerSocketChannelFactory(
                Executors.newCachedThreadPool(new ThreadFactory() {
                    @Override
                    public Thread newThread(final Runnable r) {
                        final Thread t = 
                            new Thread(r, "Daemon-Netty-Boss-Executor");
                        t.setDaemon(true);
                        return t;
                    }
                }),
                Executors.newCachedThreadPool(new ThreadFactory() {
                    @Override
                    public Thread newThread(final Runnable r) {
                        final Thread t = 
                            new Thread(r, "Daemon-Netty-Worker-Executor");
                        t.setDaemon(true);
                        return t;
                    }
                })));

        bootstrap.setPipelineFactory(pipelineFactory);
        
        // We always only bind to localhost here for better security.
        final Channel channel = 
            bootstrap.bind(new InetSocketAddress("127.0.0.1", port));
        allChannels.add(channel);
        
        return bootstrap;
    }


    private ChannelPipelineFactory newHttpChannelPipelineFactory() {
        final XmppHandler xmpp = LanternHub.xmppHandler();
        return new ChannelPipelineFactory() {
            @Override
            public ChannelPipeline getPipeline() throws Exception {
                log.info("Building pipeline...");
                final SimpleChannelUpstreamHandler handler = 
                    new DispatchingProxyRelayHandler(xmpp, xmpp, 
                        xmpp.getP2PClient(), keyStoreManager);
                final ChannelPipeline pipeline = pipeline();
                pipeline.addLast("decoder", 
                    new HttpRequestDecoder(8192, 8192*2, 8192*2));
                pipeline.addLast("encoder", 
                    new LanternHttpResponseEncoder(LanternHub.statsTracker()));
                pipeline.addLast("handler", handler);
                return pipeline;
            }
        };
    }
}
