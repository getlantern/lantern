package org.lantern.udtrelay;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.ChannelOption;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.nio.NioServerSocketChannel;

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
    }
}
