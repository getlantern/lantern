package org.lantern;

import io.netty.bootstrap.Bootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.udt.UdtChannel;
import io.netty.channel.udt.nio.NioUdtProvider;
import io.netty.handler.logging.LogLevel;
import io.netty.handler.logging.LoggingHandler;

import java.util.concurrent.ThreadFactory;

import org.junit.Test;
import org.lantern.util.Threads;

public class UdtRelayServerTest {

    @Test
    public void test() throws Exception {
        final int serverPort = LanternUtils.randomPort();
        final int relayPort = LanternUtils.randomPort();
        final UdtRelayServer server = new UdtRelayServer(serverPort, relayPort);
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                try {
                    server.run();
                } catch (final Exception e) {
                    e.printStackTrace();
                }
            }
        });
        t.setDaemon(true);
        t.start();
        
        Thread.sleep(1000);
        connectClient("127.0.0.1", serverPort);
    }
    

    private void connectClient(final String host, final int port) throws Exception {
        // Configure the client.
        final int messageSize = 10;
        final Bootstrap boot = new Bootstrap();
        final ThreadFactory connectFactory = 
            Threads.newThreadFactory("connect");
        final NioEventLoopGroup connectGroup = new NioEventLoopGroup(1,
                connectFactory, NioUdtProvider.BYTE_PROVIDER);
        try {
            boot.group(connectGroup)
                .channelFactory(NioUdtProvider.BYTE_CONNECTOR)
                .handler(new ChannelInitializer<UdtChannel>() {
                    @Override
                    public void initChannel(final UdtChannel ch)
                            throws Exception {
                        ch.pipeline().addLast(
                                new LoggingHandler(LogLevel.INFO),
                                new UdtClientRelayHandler(messageSize));
                    }
                });
            // Start the client.
            final ChannelFuture f = boot.connect(host, port).sync();
            f.channel().write("TEST");
            // Wait until the connection is closed.
            f.channel().closeFuture().sync();
        } finally {
            // Shut down the event loop to terminate all threads.
            boot.shutdown();
        }
    }

}
