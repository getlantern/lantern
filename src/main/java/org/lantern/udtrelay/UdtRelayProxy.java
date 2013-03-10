package org.lantern.udtrelay;

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

import org.lantern.util.Threads;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class UdtRelayProxy {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final int localPort;
    private final String remoteHost;
    private final int remotePort;

    public UdtRelayProxy(final int localPort, 
        final String remoteHost, final int remotePort) {
        this.localPort = localPort;
        this.remoteHost = remoteHost;
        this.remotePort = remotePort;
    }

    public void run() throws Exception {
        log.debug("Proxying clients from 127.0.0.1:" + localPort + " to " +
            remoteHost + ':' + remotePort + " ...");

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
                            new LoggingHandler(LogLevel.INFO),
                            new UdtRelayServerIncomingHandler(remoteHost, remotePort));
                    }
                });
            
            final ChannelFuture future = boot.bind("127.0.0.1", localPort).sync();
            // Start the server.
            //final ChannelFuture future = boot.bind(port).sync();
            // Wait until the server socket is closed.
            future.channel().closeFuture().sync();
        } finally {
            // Shut down all event loops to terminate all threads.
            boot.shutdown();
        }
        
        
        /*
        // Configure the bootstrap.
        final ServerBootstrap sb = new ServerBootstrap();
        try {
            sb.group(new NioEventLoopGroup(), new NioEventLoopGroup())
                .channel(NioServerSocketChannel.class)
                .childHandler(new UdtRelayInitializer(remoteHost, remotePort))
                .childOption(ChannelOption.AUTO_READ, false)
                .bind("127.0.0.1", localPort).sync().channel().closeFuture().sync();
                //.bind("127.0.0.1", localPort).sync().channel();
        } finally {
            sb.shutdown();
        }
        */
    }
}
