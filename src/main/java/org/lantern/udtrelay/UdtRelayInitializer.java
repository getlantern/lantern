package org.lantern.udtrelay;

import io.netty.channel.ChannelInitializer;
import io.netty.channel.socket.SocketChannel;
import io.netty.handler.logging.LogLevel;
import io.netty.handler.logging.LoggingHandler;

/**
 * Initializer for incoming UDT traffic that always creates a connection
 * to the destination server as soon as a client connection comes in.
 */
public class UdtRelayInitializer extends ChannelInitializer<SocketChannel> {

    private final String remoteHost;
    private final int remotePort;

    public UdtRelayInitializer(final String remoteHost, final int remotePort) {
        this.remoteHost = remoteHost;
        this.remotePort = remotePort;
    }

    @Override
    public void initChannel(final SocketChannel ch) throws Exception {
        ch.pipeline().addLast(
            new LoggingHandler(LogLevel.INFO),
            new UdtRelayFrontendHandler(remoteHost, remotePort));
    }
}
