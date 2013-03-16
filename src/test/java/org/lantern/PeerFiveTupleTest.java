package org.lantern;

import static org.junit.Assert.assertTrue;
import io.netty.bootstrap.Bootstrap;
import io.netty.buffer.ByteBuf;
import io.netty.channel.ChannelInboundByteHandlerAdapter;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.udt.UdtChannel;
import io.netty.channel.udt.nio.NioUdtProvider;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketAddress;
import java.net.URI;
import java.util.HashMap;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

import org.apache.commons.lang.StringUtils;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelConfig;
import org.jboss.netty.channel.ChannelFactory;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.junit.Ignore;
import org.junit.Test;
import org.lantern.util.NettyUtils;
import org.lantern.util.Threads;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.util.FiveTuple;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.barchart.udt.net.NetSocketUDT;

@Ignore
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
        IceConfig.setTcp(false);
        Launcher.configureCipherSuites();
        TestUtils.load(true);
        final DefaultXmppHandler xmpp = TestUtils.getXmppHandler();
        xmpp.connect();
        XmppP2PClient<FiveTuple> client = xmpp.getP2PClient();
        int attempts = 0;
        while (client == null && attempts < 100) {
            Thread.sleep(100);
            client = xmpp.getP2PClient();
            attempts++;
        }
        
        assertTrue("Still no p2p client!!?!?!", client != null);
        
        // ENTER A PEER TO RUN LIVE TESTS -- THEY NEED TO BE ON THE NETWORK.
        final String peer = "lanternftw@gmail.com/-lan-E0E144E0";
        if (StringUtils.isBlank(peer)) {
            return;
        }
        final URI uri = new URI(peer);

        final FiveTuple s = LanternUtils.openOutgoingPeer(uri, 
                xmpp.getP2PClient(), 
            new HashMap<URI, AtomicInteger>());
        
        System.err.println("************************************GOT 5 TUPLE!!!!");
        final InetSocketAddress local = s.getLocal();
        final InetSocketAddress remote = s.getRemote();
        //run(remote.getAddress().getHostAddress(), remote.getPort());
        hitRelayUdt(remote);
        
        /*
        final HttpRequest request = 
            new org.jboss.netty.handler.codec.http.DefaultHttpRequest(
                HttpVersion.HTTP_1_1, HttpMethod.HEAD, 
                "http://lantern.s3.amazonaws.com/windows-x86-1.7.0_03.tar.gz");
        
        request.addHeader("Host", "lantern.s3.amazonaws.com");
        request.addHeader("Proxy-Connection", "Keep-Alive");
        
        final AtomicReference<Object> writtenOnChannel = new AtomicReference<Object>();
        final AtomicBoolean connected = new AtomicBoolean(false);
        Channel incomingChannel = newChannel(writtenOnChannel);
        //hitRelayUdt(remote, "");
        openOutgoingChannel(incomingChannel, request, s, connected);
        //LanternUtils.writeRequest(request, cf);
        //cf.channel().write(message)
        Thread.sleep(10000);
        //assertTrue("Not connected?!?", connected.get());
        System.err.println("GOT ON CHANNEL"+writtenOnChannel.get());
        assertTrue(writtenOnChannel.get() != null);
        */
    }
    

    private io.netty.channel.ChannelFuture openOutgoingChannel(
        final Channel browserToProxyChannel, final HttpRequest request, 
        final FiveTuple fiveTuple, final AtomicBoolean connected) throws InterruptedException {
        browserToProxyChannel.setReadable(false);

        final Bootstrap boot = new Bootstrap();
        final ThreadFactory connectFactory = 
            Threads.newNonDaemonThreadFactory("connect");
        final NioEventLoopGroup connectGroup = new NioEventLoopGroup(1,
                connectFactory, NioUdtProvider.BYTE_PROVIDER);

        try {
            boot.group(connectGroup)
                .channelFactory(NioUdtProvider.BYTE_CONNECTOR)
                .handler(new ChannelInitializer<UdtChannel>() {
                    @Override
                    public void initChannel(final UdtChannel ch) 
                        throws Exception {
                        final io.netty.channel.ChannelPipeline p = ch.pipeline();
                        p.addLast(
                            //new LoggingHandler(LogLevel.INFO),
                            new HttpResponseClientHandler(
                                browserToProxyChannel, request));
                    }
                });
            // Start the client.
            
            // We need to bind to the local address here, as that's what is
            // NAT/firewall traversed (anything else might not work).
            try {
                boot.bind(fiveTuple.getLocal()).sync();
            } catch (final InterruptedException e) {
                log.error("Could not sync on bind? Reuse address no working?", e);
            }
            boot.connect(fiveTuple.getRemote()).sync();
            
            /*
            final ChannelFuture cf = boot.connect(fiveTuple.getRemote());
            cf.addListener(new ChannelFutureListener() {
                
                @Override
                public void operationComplete(final ChannelFuture future) 
                    throws Exception {
                    if (future.isSuccess()) {
                        log.debug("CONNECTED");
                        connected.set(true);
                        browserToProxyChannel.setReadable(true);
                    } else {
                        log.debug("Could not connect?");
                    }
                }
            });
            return cf;
            */
            return null;
        } finally {
            // Shut down the event loop to terminate all threads.
            boot.shutdown();
        }
    }
    

    private static class HttpResponseClientHandler extends ChannelInboundByteHandlerAdapter {

        private static final Logger log = 
                LoggerFactory.getLogger(HttpResponseClientHandler.class);


        private final Channel browserToProxyChannel;


        private final HttpRequest httpRequest;

        private HttpResponseClientHandler(
            final Channel browserToProxyChannel, final HttpRequest httpRequest) {
            this.browserToProxyChannel = browserToProxyChannel;
            this.httpRequest = httpRequest;
        }

        @Override
        public void channelActive(final io.netty.channel.ChannelHandlerContext ctx) throws Exception {
            log.debug("Channel active " + NioUdtProvider.socketUDT(ctx.channel()).toStringOptions());
            ctx.write(NettyUtils.encoder.encode(httpRequest)).sync();
        }

        @Override
        public void inboundBufferUpdated(final io.netty.channel.ChannelHandlerContext ctx,
                final ByteBuf in) {
            
            // TODO: We should be able to do this more efficiently than
            // converting to a string and back out.
            final String response = in.toString(LanternConstants.UTF8);
            log.debug("INBOUND UPDATED!!\n"+response);
            
            synchronized (browserToProxyChannel) {
                final ChannelBuffer wrapped = 
                    ChannelBuffers.wrappedBuffer(response.getBytes());
                this.browserToProxyChannel.write(wrapped);
                this.browserToProxyChannel.notifyAll();
            }
        }

        @Override
        public void exceptionCaught(final io.netty.channel.ChannelHandlerContext ctx,
                final Throwable cause) {
            log.debug("close the connection when an exception is raised", cause);
            ctx.close();
        }

        @Override
        public ByteBuf newInboundBuffer(final io.netty.channel.ChannelHandlerContext ctx)
                throws Exception {
            log.debug("NEW INBOUND BUFFER");
            return ctx.alloc().directBuffer(
                    ctx.channel().config().getOption(ChannelOption.SO_RCVBUF));
        }

    }
    
    
    private static final String REQUEST =
        "HEAD http://lantern.s3.amazonaws.com/windows-x86-1.7.0_03.tar.gz HTTP/1.1\r\n"+
        "Host: lantern.s3.amazonaws.com\r\n"+
        "Proxy-Connection: Keep-Alive\r\n"+
        "User-Agent: Apache-HttpClient/4.2.2 (java 1.5)\r\n" +
        "\r\n";
    
    private void hitRelayUdt(final InetSocketAddress socketAddress) throws Exception {
        final Socket plainText = new NetSocketUDT();
        plainText.connect(socketAddress);
        
        final SSLSocket ssl =
            (SSLSocket)((SSLSocketFactory)TestUtils.getSocketsUtil().newTlsSocketFactory()).createSocket(plainText, 
                    plainText.getInetAddress().getHostAddress(), 
                    plainText.getPort(), true);
        
        final SSLSocket sock = ssl;
        sock.setUseClientMode(true);
        sock.startHandshake();
        
        sock.getOutputStream().write(REQUEST.getBytes());
        
        final InputStream is = sock.getInputStream();
        sock.setSoTimeout(4000);
        final BufferedReader br = new BufferedReader(new InputStreamReader(is));
        final StringBuilder sb = new StringBuilder();
        String cur = br.readLine();
        sb.append(cur);
        while(StringUtils.isNotBlank(cur)) {
            System.err.println(cur);
            cur = br.readLine();
            if (!cur.startsWith("x-amz-") && !cur.startsWith("Date")) {
                sb.append(cur);
                sb.append("\n");
            }
        }
        
        final String response = sb.toString();
        plainText.close();
        assertTrue("Unexpected response "+response, 
            response.startsWith("HTTP/1.1 200 OK"));
    }

    private Channel newChannel(final AtomicReference<Object> writtenOnChannel) {
        return new org.jboss.netty.channel.Channel() {

            @Override
            public int compareTo(Channel arg0) {
                // TODO Auto-generated method stub
                return 0;
            }

            @Override
            public Integer getId() {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public ChannelFactory getFactory() {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public Channel getParent() {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public ChannelConfig getConfig() {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public ChannelPipeline getPipeline() {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public boolean isOpen() {
                // TODO Auto-generated method stub
                return false;
            }

            @Override
            public boolean isBound() {
                // TODO Auto-generated method stub
                return false;
            }

            @Override
            public boolean isConnected() {
                // TODO Auto-generated method stub
                return false;
            }

            @Override
            public SocketAddress getLocalAddress() {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public SocketAddress getRemoteAddress() {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public org.jboss.netty.channel.ChannelFuture write(Object message) {
                writtenOnChannel.set(message);
                return null;
            }

            @Override
            public org.jboss.netty.channel.ChannelFuture write(Object message,
                    SocketAddress remoteAddress) {
                writtenOnChannel.set(message);
                return null;
            }

            @Override
            public org.jboss.netty.channel.ChannelFuture bind(
                    SocketAddress localAddress) {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public org.jboss.netty.channel.ChannelFuture connect(
                    SocketAddress remoteAddress) {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public org.jboss.netty.channel.ChannelFuture disconnect() {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public org.jboss.netty.channel.ChannelFuture unbind() {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public org.jboss.netty.channel.ChannelFuture close() {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public org.jboss.netty.channel.ChannelFuture getCloseFuture() {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public int getInterestOps() {
                // TODO Auto-generated method stub
                return 0;
            }

            @Override
            public boolean isReadable() {
                // TODO Auto-generated method stub
                return false;
            }

            @Override
            public boolean isWritable() {
                // TODO Auto-generated method stub
                return false;
            }

            @Override
            public org.jboss.netty.channel.ChannelFuture setInterestOps(
                    int interestOps) {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public org.jboss.netty.channel.ChannelFuture setReadable(
                    boolean readable) {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public Object getAttachment() {
                // TODO Auto-generated method stub
                return null;
            }

            @Override
            public void setAttachment(Object attachment) {
                // TODO Auto-generated method stub
                
            }
            
        };
    }
}
