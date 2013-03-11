package org.lantern.udtrelay;

import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.nio.NioServerSocketChannel;
import io.netty.channel.udt.UdtChannel;
import io.netty.channel.udt.nio.NioUdtProvider;

import java.util.concurrent.ThreadFactory;

import org.lantern.LanternClientConstants;
import org.lantern.util.Threads;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class UdtRelayProxy {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final int localPort;
    private final int destinationPort;

    public UdtRelayProxy(final int localPort, final int remotePort) {
        this.localPort = localPort;
        this.destinationPort = remotePort;
    }

    public void run() throws Exception {
        log.debug("Proxying clients from 127.0.0.1:" + localPort + " to " +
            "127.0.0.1:" + destinationPort + " ...");

        final ThreadFactory acceptFactory = Threads.newThreadFactory("accept");
        final ThreadFactory connectFactory = Threads.newThreadFactory("connect");
        final NioEventLoopGroup acceptGroup = new NioEventLoopGroup(1,
                acceptFactory, NioUdtProvider.BYTE_PROVIDER);
        final NioEventLoopGroup connectGroup = new NioEventLoopGroup(1,
                connectFactory, NioUdtProvider.BYTE_PROVIDER);
        // Configure the server.
        final ServerBootstrap boot = new ServerBootstrap();
        try {
            boot.group(acceptGroup, connectGroup)
                .channelFactory(NioUdtProvider.BYTE_ACCEPTOR)
                .option(ChannelOption.SO_BACKLOG, 10)
                //.handler(new LoggingHandler(LogLevel.INFO))
                //.childHandler(new UdtRelayInitializer(remoteHost, remotePort))
                //.childOption(ChannelOption.AUTO_READ, false)
            
                /*
                .childHandler(new ChannelInitializer<UdtChannel>() {
                    @Override
                    public void initChannel(final UdtChannel ch)
                            throws Exception {
                        ch.pipeline().addLast(
                            new LoggingHandler(LogLevel.INFO),
                            new UdtRelayFrontendHandler(remoteHost, remotePort));
                    }
                });
                */
            
                .childHandler(new ChannelInitializer<UdtChannel>() {
                    @Override
                    public void initChannel(final UdtChannel ch)
                            throws Exception {
                        ch.pipeline().addLast(
                            //new LoggingHandler(LogLevel.INFO),x
                            new UdtRelayServerIncomingHandler(destinationPort));
                    }
                });
            
            final ChannelFuture future = boot.bind("127.0.0.1", localPort).sync();
            // Wait until the server socket is closed.
            future.channel().closeFuture().sync();
        } finally {
            // Shut down all event loops to terminate all threads.
            boot.shutdown();
        }
    }
    
    public void runTcp() throws Exception {
        // Configure the bootstrap.
        final ServerBootstrap sb = new ServerBootstrap();
        try {
            sb.group(new NioEventLoopGroup(), new NioEventLoopGroup())
                .channel(NioServerSocketChannel.class)
                .childHandler(new UdtRelayInitializer(destinationPort))
                .childOption(ChannelOption.AUTO_READ, false)
                .bind(LanternClientConstants.LOCALHOST, localPort).sync().channel().closeFuture().sync();
                //.bind("127.0.0.1", localPort).sync().channel();
        } finally {
            sb.shutdown();
        }
    }
}
