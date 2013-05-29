package org.lantern.udtrelay;

import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;
import io.netty.bootstrap.Bootstrap;
import io.netty.buffer.ByteBuf;
import io.netty.buffer.Unpooled;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundByteHandlerAdapter;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.ChannelPipeline;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.udt.UdtChannel;
import io.netty.channel.udt.nio.NioUdtProvider;
import io.netty.handler.ssl.SslHandler;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketAddress;
import java.net.URI;
import java.util.concurrent.ThreadFactory;

import javax.net.ssl.SSLEngine;

import org.apache.commons.lang3.StringUtils;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.AbstractChannel;
import org.jboss.netty.channel.AbstractChannelSink;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelConfig;
import org.jboss.netty.channel.ChannelEvent;
import org.jboss.netty.channel.ChannelPipelineException;
import org.jboss.netty.channel.ChannelSink;
import org.jboss.netty.channel.Channels;
import org.jboss.netty.channel.DefaultChannelConfig;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioServerSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.codec.http.HttpVersion;
import org.jboss.netty.util.HashedWheelTimer;
import org.junit.Test;
import org.lantern.CertTrackingSslHandlerFactory;
import org.lantern.LanternClientConstants;
import org.lantern.LanternConstants;
import org.lantern.LanternKeyStoreManager;
import org.lantern.LanternTrustStore;
import org.lantern.LanternUtils;
import org.lantern.StatsTrackingDefaultHttpProxyServer;
import org.lantern.util.Threads;
import org.littleshoot.proxy.DefaultHttpProxyServer;
import org.littleshoot.proxy.HandshakeHandlerFactory;
import org.littleshoot.proxy.HttpFilter;
import org.littleshoot.proxy.HttpResponseFilters;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.FiveTuple.Protocol;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class UdtRelayTest {

    private final static Logger log = LoggerFactory.getLogger(UdtRelayTest.class);
    
    @Test
    public void test() throws Exception {
        // The idea here is to start an HTTP proxy server locally that the UDT
        // relay relays to -- i.e. just like the real world setup.
        
        final LanternKeyStoreManager ksm = new LanternKeyStoreManager();
        
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        final String dummyId = "test@gmail.com/-lan-22LJDEE";
        
        trustStore.addBase64Cert(new URI(dummyId), ksm.getBase64Cert(dummyId));
        
        final HandshakeHandlerFactory hhf = 
                new CertTrackingSslHandlerFactory(new HashedWheelTimer(), trustStore);
        
        // Note that an internet connection is required to run this test.
        final int proxyPort = LanternUtils.randomPort();
        final int relayPort = LanternUtils.randomPort();
        startProxyServer(proxyPort, hhf, true);
        final InetSocketAddress localRelayAddress = 
            new InetSocketAddress(LanternClientConstants.LOCALHOST, relayPort);
        
        
        final UdtRelayProxy relay = 
            new UdtRelayProxy(localRelayAddress, proxyPort);
        startRelay(relay);
        
        // We do this a few times to make sure there are no issues with 
        // subsequent runs.
        for (int i = 0; i < 1; i++) {
            final String uri = "http://lantern.s3.amazonaws.com/windows-x86-1.7.0_03.tar.gz";
            final HttpRequest request = 
                new org.jboss.netty.handler.codec.http.DefaultHttpRequest(
                    HttpVersion.HTTP_1_1, HttpMethod.HEAD, uri);
            
            request.addHeader("Host", "lantern.s3.amazonaws.com");
            request.addHeader("Proxy-Connection", "Keep-Alive");
            hitRelayUdtNetty(createDummyChannel(), request, 
                new FiveTuple(null, localRelayAddress, Protocol.TCP), trustStore);
        }
    }
    
    private static final String REQUEST =
            "HEAD http://lantern.s3.amazonaws.com/windows-x86-1.7.0_03.tar.gz HTTP/1.1\r\n"+
            "Host: lantern.s3.amazonaws.com\r\n"+
            "Proxy-Connection: Keep-Alive\r\n"+
            "User-Agent: Apache-HttpClient/4.2.2 (java 1.5)\r\n" +
            "\r\n";
    
    private void startProxyServer(final int port,
        final HandshakeHandlerFactory ksm, final boolean ssl) throws Exception {
        
        // We configure the proxy server to always return a cache hit with 
        // the same generic response.
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                if (ssl) {
                    org.jboss.netty.util.Timer timer = 
                        new org.jboss.netty.util.HashedWheelTimer();
                    final org.lantern.HttpProxyServer server = 
                        new StatsTrackingDefaultHttpProxyServer(
                        new HttpResponseFilters() {
                            @Override
                            public HttpFilter getFilter(String arg0) {
                                return null;
                            }
                        }, null, null,
                        new NioClientSocketChannelFactory(), timer,
                        new NioServerSocketChannelFactory(), ksm, null,
                        null) {
                            @Override
                            public int getPort() {
                                return port;
                            }
                    };
                    try {
                        server.start();
                    } catch (final Exception e) {
                        log.error("Error starting server!!", e);
                    }
                } else {
                    final org.littleshoot.proxy.HttpProxyServer server =
                            new DefaultHttpProxyServer(port);
                    try {
                        server.start();
                    } catch (final Exception e) {
                        log.error("Error starting server!!", e);
                    }
                }
            }
        }, "Relay-to-Proxy-Test-Thread");
        t.setDaemon(true);
        t.start();
        if (!LanternUtils.waitForServer(port, 6000)) {
            fail("Could not start local test proxy server!!");
        }
    }

    private String hitProxyDirect(final int proxyPort) throws Exception {
        final Socket sock = new Socket();
        sock.connect(new InetSocketAddress("127.0.0.1", proxyPort));
        
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
        sock.close();
        assertTrue("Unexpected response "+response, 
            response.startsWith("HTTP/1.1 200 OK"));

        return response;

    }
    
    public static class DummyChannel extends AbstractChannel {
        
        ChannelConfig config;
        private String message = "";
        
        DummyChannel(final org.jboss.netty.channel.ChannelPipeline p, 
            final ChannelSink sink) {
            super(null, null, p, sink);
            config = new DefaultChannelConfig();
        }
        
        @Override public ChannelConfig getConfig() {return config;}
        
        @Override public SocketAddress getLocalAddress() { return new InetSocketAddress("127.0.0.1", 55512); }
        @Override public SocketAddress getRemoteAddress() { return new InetSocketAddress("127.0.0.1", 55513); }
        
        @Override public boolean isBound() {return true;}
        @Override public boolean isConnected() {return true;}
        
        @Override public org.jboss.netty.channel.ChannelFuture write(final Object message) {
            final ChannelBuffer cb = (ChannelBuffer) message;
            final String msg = cb.toString(LanternConstants.UTF8);
            log.debug("Got message on dummy client channel:\n{}", msg);
            this.message = msg;
            final org.jboss.netty.channel.ChannelFuture cf = super.write(message);
            //cf.setSuccess();
            return cf;
            //return Channels.write(this, message);
            //return null;
        }
    }


    public static DummyChannel createDummyChannel() {
        final org.jboss.netty.channel.ChannelPipeline pipeline = Channels.pipeline();
        final ChannelSink sink = new AbstractChannelSink() {
            @Override public void eventSunk(org.jboss.netty.channel.ChannelPipeline p, ChannelEvent e) {}
            @Override public void exceptionCaught(org.jboss.netty.channel.ChannelPipeline pipeline,
                                     ChannelEvent e,
                                     ChannelPipelineException cause)
                                     throws Exception {
                                         
                Throwable t = cause.getCause();
                if (t != null) {
                    t.printStackTrace();
                }
                super.exceptionCaught(pipeline,e,cause);
            }
            
        };

        return new DummyChannel(pipeline, sink);
    }
    
    private void hitRelayUdtNetty(
        final DummyChannel browserToProxyChannel, final HttpRequest request,
        final FiveTuple ft, final LanternTrustStore trustStore) throws Exception {
        browserToProxyChannel.setReadable(false);
        
        final Bootstrap boot = new Bootstrap();
        final ThreadFactory connectFactory = 
                Threads.newNonDaemonThreadFactory("connect");
        final NioEventLoopGroup connectGroup = new NioEventLoopGroup(1,
                connectFactory, NioUdtProvider.BYTE_PROVIDER);

        try {
            boot.group(connectGroup)
                .channelFactory(NioUdtProvider.BYTE_CONNECTOR)
                .option(ChannelOption.SO_REUSEADDR, true)
                .handler(new ChannelInitializer<UdtChannel>() {
                    @Override
                    public void initChannel(final UdtChannel ch)
                            throws Exception {
                        final ChannelPipeline p = ch.pipeline();
                        final SSLEngine engine = 
                            trustStore.getClientContext().createSSLEngine();
                        
                        //SSLEngine serverEngine = sslc.createSSLEngine();
                        engine.setUseClientMode(true);

                        p.addLast("ssl", new SslHandler(engine));
                        p.addLast(
                            //new LoggingHandler(LogLevel.INFO),
                            new HttpResponseClientHandler(
                                browserToProxyChannel, request));
                    }
                });
            /*
            try {
                boot.bind(ft.getLocal()).sync();
            } catch (final InterruptedException e) {
                log.error("Could not sync on bind? Reuse address no working?", e);
            }
            */
            
            // Start the client.
            final ChannelFuture f = 
                boot.connect(ft.getRemote(), ft.getLocal()).sync();
            
            log.debug("Got connected!! Encoding request");
            f.channel().write(encoder.encode(request)).sync();
            
            synchronized(browserToProxyChannel) {
                if (browserToProxyChannel.message.length() == 0) {
                    browserToProxyChannel.wait(4000);
                }
            }
            
            assertTrue("Unexpected response. Beginning is:\n"+
                    browserToProxyChannel.message.substring(0, 200),
                    // Can apparently get HTTP 1.0 responses in some cases...
                    browserToProxyChannel.message.startsWith("HTTP/1.1 200 OK") ||
                    browserToProxyChannel.message.startsWith("HTTP/1.0 200 OK"));
            
            f.channel().close();
            
        } finally {
            // Shut down the event loop to terminate all threads.
            //boot.shutdown();
        }
    }
    
    private static final class HttpRequestConverter extends HttpRequestEncoder {
        private Channel basicChannel = new ChannelAdapter();

        public ByteBuf encode(final HttpRequest request) throws Exception {
            final ChannelBuffer cb = (ChannelBuffer) super.encode(null, basicChannel, request);
            return Unpooled.wrappedBuffer(cb.toByteBuffer());
        }
    };
    
    private static final HttpRequestConverter encoder = new HttpRequestConverter();
    
    private static class HttpResponseClientHandler extends ChannelInboundByteHandlerAdapter {

        private static final Logger log = 
                LoggerFactory.getLogger(HttpResponseClientHandler.class);

        //private final ByteBuf message = Unpooled.wrappedBuffer(REQUEST.getBytes());

        private final Channel browserToProxyChannel;

        private HttpResponseClientHandler(
            final Channel browserToProxyChannel, final HttpRequest request) {
            this.browserToProxyChannel = browserToProxyChannel;
            //this.httpRequest = request;
        }

        @Override
        public void channelActive(final ChannelHandlerContext ctx) throws Exception {
            log.info("Channel active " + NioUdtProvider.socketUDT(ctx.channel()).toStringOptions());
            
            //ctx.write(encoder.encode(httpRequest));
        }

        @Override
        public void inboundBufferUpdated(final ChannelHandlerContext ctx,
                final ByteBuf in) {
            final String response = in.toString(LanternConstants.UTF8);
            log.info("INBOUND UPDATED!!\n"+response);
            
            
            synchronized (browserToProxyChannel) {
                final ChannelBuffer wrapped = ChannelBuffers.wrappedBuffer(response.getBytes());
                this.browserToProxyChannel.write(wrapped);
                this.browserToProxyChannel.notifyAll();
            }
        }

        @Override
        public void exceptionCaught(final ChannelHandlerContext ctx,
                final Throwable cause) {
            log.debug("close the connection when an exception is raised", cause);
            ctx.close();
        }

        @Override
        public ByteBuf newInboundBuffer(final ChannelHandlerContext ctx)
                throws Exception {
            log.info("NEW INBOUND BUFFER");
            return ctx.alloc().directBuffer(
                    ctx.channel().config().getOption(ChannelOption.SO_RCVBUF));
        }

    }
    
    private void startRelay(final UdtRelayProxy relay) throws Exception {
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                try {
                    relay.run();
                } catch (Exception e) {
                    throw new RuntimeException("Error running server", e);
                }
            }
        }, "Relay-Test-Thread");
        t.setDaemon(true);
        t.start();
        // Just sleep to wait for it to start for UDT...
        Thread.sleep(400);
    }

}
