package org.lantern;

import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.udt.UdtChannel;
import io.netty.channel.udt.nio.NioUdtProvider;
import io.netty.handler.logging.LogLevel;
import io.netty.handler.logging.LoggingHandler;

import java.util.concurrent.ThreadFactory;
import java.util.logging.Logger;

import org.lantern.util.Threads;

/**
 * UDT Message Flow Server
 * <p>
 * Echoes back any received data from a client.
 */
public class UdtRelayServer {

    private static final Logger log = 
            Logger.getLogger(UdtRelayServer.class.getName());

    private final int serverPort;

    private final int relayPort;

    public UdtRelayServer(final int serverPort, final int relayPort) {
        this.serverPort = serverPort;
        this.relayPort = relayPort;
    }

    public void run() throws Exception {
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
                .handler(new LoggingHandler(LogLevel.INFO))
                .childHandler(new ChannelInitializer<UdtChannel>() {
                    @Override
                    public void initChannel(final UdtChannel ch)
                            throws Exception {
                        ch.pipeline().addLast(
                                new LoggingHandler(LogLevel.INFO),
                                new UdtRelayServerHandler(relayPort));
                    }
                });
            // Start the server.
            //final ChannelFuture future = boot.bind(serverPort).sync();
            final ChannelFuture future = boot.bind("127.0.0.1", serverPort).sync();
            // Wait until the server socket is closed.
            future.channel().closeFuture().sync();
        } finally {
            // Shut down all event loops to terminate all threads.
            boot.shutdown();
        }
    }

}
