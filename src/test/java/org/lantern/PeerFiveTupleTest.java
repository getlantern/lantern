package org.lantern;

import io.netty.bootstrap.Bootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.udt.UdtChannel;
import io.netty.channel.udt.nio.NioUdtProvider;
import io.netty.handler.logging.LogLevel;
import io.netty.handler.logging.LoggingHandler;

import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.commons.lang.StringUtils;
import org.junit.Test;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.littleshoot.util.FiveTuple;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


public class PeerFiveTupleTest {
    
    private final Logger log = LoggerFactory.getLogger(getClass());

    final int messageSize = 64 * 1024;
    
    @Test
    public void testSocket() throws Exception {
        
        //System.setProperty("javax.net.debug", "ssl");
        
        // Note you have to have a remote peer URI that's up a running for
        // this test to work. In the future we'll likely develop a test
        // framework that simulates things like unpredictable network latency
        // and doesn't require live tests over the network.
        IceConfig.setDisableUdpOnLocalNetwork(false);
        Launcher.configureCipherSuites();
        TestUtils.load(true);
        final DefaultXmppHandler xmpp = TestUtils.getXmppHandler();
        xmpp.connect();

        Thread.sleep(2000);
        // ENTER A PEER TO RUN LIVE TESTS -- THEY NEED TO BE ON THE NETWORK.
        final String peer = "lanternftw@gmail.com/-lan-FEC3E7C0";
        if (StringUtils.isBlank(peer)) {
            return;
        }
        final URI uri = new URI(peer);
        IceConfig.setTcp(false);

        final Collection<Socket> socks = new ArrayList<Socket>();
        for (int i = 0; i < 40; i++) {
            final long start = System.currentTimeMillis();
            try {
                /*
                final FiveTuple s = LanternUtils.openOutgoingPeer(uri, 
                        xmpp.getP2PClient(), 
                    new HashMap<URI, AtomicInteger>());
                
                System.err.println("************************************GOT 5 TUPLE!!!!");
                final InetSocketAddress local = s.getLocal();
                final InetSocketAddress remote = s.getRemote();
                run(remote.getAddress().getHostAddress(), remote.getPort());
                */
                
            } catch (final Exception e) {
                log.error("Error connecting on pass "+i);
                throw e;
            }
        }
        Thread.sleep(10000);
        for (final Socket sock : socks) {
            sock.close();
        }
    }
    
    private void run(final String host, final int port) throws Exception {
        // Configure the client.
        final Bootstrap boot = new Bootstrap();
        final ThreadFactory connectFactory = new UtilThreadFactory("connect");
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
            // Wait until the connection is closed.
            f.channel().closeFuture().sync();
        } finally {
            // Shut down the event loop to terminate all threads.
            boot.shutdown();
        }
    }
    
    /**
     * Custom thread factory to use with examples.
     */
    private static class UtilThreadFactory implements ThreadFactory {

        private static final AtomicInteger counter = new AtomicInteger();

        private final String name;

        public UtilThreadFactory(final String name) {
            this.name = name;
        }

        @Override
        public Thread newThread(final Runnable runnable) {
            return new Thread(runnable, name + '-' + counter.getAndIncrement());
        }
    }
}
