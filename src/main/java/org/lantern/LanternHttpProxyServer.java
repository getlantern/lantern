package org.lantern;

import static org.jboss.netty.channel.Channels.pipeline;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.lang.Thread.UncaughtExceptionHandler;
import java.net.InetSocketAddress;
import java.util.Collection;
import java.util.HashSet;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
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

    private final int sslProxyRandomPort;

    private final int plainTextProxyRandomPort;

    private final int httpsLocalPort;
    
    /**
     * Creates a new proxy server.
     * 
     * @param httpLocalPort The port the HTTP server should run on.
     * @param httpsLocalPort The port the HTTPS server should run on.
     * @param filters HTTP filters to apply.
     * @param sslProxyRandomPort The port of the HTTP proxy that other peers  
     * will relay to.
     * @param plainTextProxyRandomPort The port of the HTTP proxy running
     * only locally and accepting plain-text sockets.
     */
    public LanternHttpProxyServer(final int httpLocalPort, 
        final int httpsLocalPort, final KeyStoreManager keyStoreManager, 
        final int sslProxyRandomPort, 
        final int plainTextProxyRandomPort) {
        this.httpLocalPort = httpLocalPort;
        this.httpsLocalPort = httpsLocalPort;
        this.keyStoreManager = keyStoreManager;
        this.sslProxyRandomPort = sslProxyRandomPort;
        this.plainTextProxyRandomPort = plainTextProxyRandomPort;
        Thread.setDefaultUncaughtExceptionHandler(new UncaughtExceptionHandler() {
            public void uncaughtException(final Thread t, final Throwable e) {
                log.error("Uncaught exception", e);
            }
        });
    }
    

    public void start() {
        log.info("Starting proxy on HTTP port "+httpLocalPort+
            " and HTTPS port "+httpsLocalPort);
        final Collection<String> whitelist = buildWhitelist();
        final XmppHandler xmpp = 
            new XmppHandler(keyStoreManager, sslProxyRandomPort, 
                plainTextProxyRandomPort);
        
        newServerBootstrap(newHttpChannelPipelineFactory(whitelist, xmpp), 
            httpLocalPort);
        log.info("Build HTTP server");
        
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
                    public Thread newThread(final Runnable r) {
                        final Thread t = 
                            new Thread(r, "Daemon-Netty-Boss-Executor");
                        t.setDaemon(true);
                        return t;
                    }
                }),
                Executors.newCachedThreadPool(new ThreadFactory() {
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


    private ChannelPipelineFactory newHttpChannelPipelineFactory(
        final Collection<String> whitelist, final XmppHandler xmpp) {
        return new ChannelPipelineFactory() {
            public ChannelPipeline getPipeline() throws Exception {
                log.info("Building pipeline...");
                final SimpleChannelUpstreamHandler handler = 
                    new DispatchingProxyRelayHandler(xmpp, xmpp, whitelist, 
                        xmpp.getP2PClient());
                final ChannelPipeline pipeline = pipeline();
                pipeline.addLast("decoder", new HttpRequestDecoder());
                pipeline.addLast("encoder", new ProxyHttpResponseEncoder());
                pipeline.addLast("handler", handler);
                return pipeline;
            }
        };
    }

    private Collection<String> buildWhitelist() {
        final Collection<String> whitelist = new HashSet<String>();
        final File file = new File("whitelist.txt");
        BufferedReader br = null;
        try {
            br = new BufferedReader(new FileReader(file));
            String site = br.readLine();
            while (site != null) {
                site = site.trim();
                if (StringUtils.isNotBlank(site)) {
                    // Ignore commented-out sites.
                    if (!site.startsWith("#")) {
                        whitelist.add(site);
                    }
                }
                else {
                    break;
                }
                site = br.readLine();
            }
        } catch (final FileNotFoundException e) {
            log.error("Could not find whitelist file!!", e);
        } catch (final IOException e) {
            log.error("Could not read whitelist file", e);
        } finally {
            IOUtils.closeQuietly(br);
        }
        return whitelist;
    }
}
