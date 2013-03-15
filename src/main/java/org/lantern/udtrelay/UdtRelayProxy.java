package org.lantern.udtrelay;

import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.udt.UdtChannel;
import io.netty.channel.udt.nio.NioUdtProvider;

import java.net.InetSocketAddress;
import java.util.concurrent.ThreadFactory;

import org.lantern.util.Threads;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class UdtRelayProxy {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final int destinationPort;

    private final InetSocketAddress local;

    public UdtRelayProxy(final InetSocketAddress local, final int localProxyPort) {
        this.local = local;
        this.destinationPort = localProxyPort;
    }

    public void run() throws Exception {
        log.debug("Proxying clients from "+ local + " to " +
            "127.0.0.1:" + destinationPort + " ...");

        final ThreadFactory acceptFactory = Threads.newThreadFactory("accept");
        final ThreadFactory connectFactory = Threads.newThreadFactory("connect");
        final NioEventLoopGroup acceptGroup = new NioEventLoopGroup(1,
                acceptFactory, NioUdtProvider.BYTE_PROVIDER);
        final NioEventLoopGroup connectGroup = new NioEventLoopGroup(1,
                connectFactory, NioUdtProvider.BYTE_PROVIDER);
        // Configure the server.
        final ServerBootstrap boot = new ServerBootstrap();
        
        // Note that we don't need to configure SSL here, as this is just a
        // simple relay that passes all bytes to the local proxy server.
        try {
            boot.group(acceptGroup, connectGroup)
                .channelFactory(NioUdtProvider.BYTE_ACCEPTOR)
                .option(ChannelOption.SO_BACKLOG, 10)
                .option(ChannelOption.SO_REUSEADDR, true)
                //.childOption(ChannelOption.SO_KEEPALIVE, true)
                //.childOption(ChannelOption.SO_TIMEOUT, 400 * 1000)
                .childHandler(new ChannelInitializer<UdtChannel>() {
                    @Override
                    public void initChannel(final UdtChannel ch)
                            throws Exception {
                        ch.pipeline().addLast(
                            //new LoggingHandler(LogLevel.INFO),x
                            new UdtRelayServerIncomingHandler(destinationPort));
                    }
                });
            
            final ChannelFuture future = boot.bind(local).sync();
            // Wait until the server socket is closed.
            future.channel().closeFuture().sync();
        } finally {
            // Shut down all event loops to terminate all threads.
            boot.shutdown();
        }
    }
}
