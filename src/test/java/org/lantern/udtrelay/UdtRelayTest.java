package org.lantern.udtrelay;

import static org.junit.Assert.assertEquals;
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
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketAddress;
import java.net.URI;
import java.util.HashMap;
import java.util.concurrent.Future;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicInteger;

import javax.net.ssl.SSLEngine;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.client.DefaultHttpRequestRetryHandler;
import org.apache.http.params.CoreConnectionPNames;
import org.apache.http.util.EntityUtils;
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
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpRequestEncoder;
import org.jboss.netty.handler.codec.http.HttpVersion;
import org.junit.Test;
import org.lantern.DefaultXmppHandler;
import org.lantern.LanternClientConstants;
import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
import org.lantern.Launcher;
import org.lantern.TestUtils;
import org.lantern.util.Threads;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.proxy.DefaultHttpProxyServer;
import org.littleshoot.proxy.HttpProxyServer;
import org.littleshoot.proxy.ProxyCacheManager;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.FiveTuple.Protocol;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.barchart.udt.net.NetSocketUDT;

public class UdtRelayTest {

    private final static Logger log = LoggerFactory.getLogger(UdtRelayTest.class);
    
    @Test
    public void test() throws Exception {
        // The idea here is to start an HTTP proxy server locally that the UDT
        // relay relays to -- i.e. just like the real world setup.
        
        final boolean udt = true;
        
        // Note that an internet connection is required to run this test.
        final int proxyPort = LanternUtils.randomPort();
        final int relayPort = LanternUtils.randomPort();
        startProxyServer(proxyPort);
        final InetSocketAddress localRelayAddress = 
            new InetSocketAddress(LanternClientConstants.LOCALHOST, relayPort);
        
        
        final UdtRelayProxy relay = 
            new UdtRelayProxy(localRelayAddress, proxyPort);
        startRelay(relay, localRelayAddress.getPort(), udt);
        
        
        // Hit the proxy directly first so we can verify we get the exact
        // same thing (except a few specific HTTP headers) from the relay.
        //final String expected = hitProxyDirect(proxyPort);
        
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
        final String peer = "lanternftw@gmail.com/-lan-4E2DD9D6";
        if (StringUtils.isBlank(peer)) {
            return;
        }
        final URI peerUri = new URI(peer);

        final FiveTuple ft = LanternUtils.openOutgoingPeer(peerUri, 
                xmpp.getP2PClient(), 
            new HashMap<URI, AtomicInteger>());
        

        // We do this a few times to make sure there are no issues with 
        // subsequent runs.
        for (int i = 0; i < 1; i++) {
            final String uri = "http://lantern.s3.amazonaws.com/windows-x86-1.7.0_03.tar.gz";
            final HttpRequest request = 
                new org.jboss.netty.handler.codec.http.DefaultHttpRequest(
                    HttpVersion.HTTP_1_1, HttpMethod.HEAD, uri);
            
            request.addHeader("Host", "lantern.s3.amazonaws.com");
            request.addHeader("Proxy-Connection", "Keep-Alive");
            if (udt) {
                //hitRelayUdtNetty(relayPort, "");
                //hitRelayUdtNetty(createDummyChannel(), request, new FiveTuple(null, localRelayAddress, Protocol.TCP));
                hitRelayUdtNetty(createDummyChannel(), request, ft);
            } else {
                hitRelayRaw(relayPort);
            }
        }
    }
    
    private static final String REQUEST =
            /*
            "GET http://www.google.com HTTP/1.1\r\n"+
            "Host: www.google.com\r\n"+
            "Proxy-Connection: Keep-Alive\r\n"+
            "User-Agent: Apache-HttpClient/4.2.2 (java 1.5)\r\n" +
            "\r\n";
            */
    
            "HEAD http://lantern.s3.amazonaws.com/windows-x86-1.7.0_03.tar.gz HTTP/1.1\r\n"+
            "Host: lantern.s3.amazonaws.com\r\n"+
            "Proxy-Connection: Keep-Alive\r\n"+
            "User-Agent: Apache-HttpClient/4.2.2 (java 1.5)\r\n" +
            "\r\n";
    /*
        "GET http://lantern.s3.amazonaws.com/windows-x86-1.7.0_03.tar.gz HTTP/1.1\r\n"+
        "Host: lantern.s3.amazonaws.com\r\n"+
        "Proxy-Connection: Keep-Alive\r\n"+
        "User-Agent: Apache-HttpClient/4.2.2 (java 1.5)\r\n" +
        "\r\n";
        
        
    /*
    GET http://lantern.s3.amazonaws.com/windows-x86-1.7.0_03.tar.gz HTTP/1.1
        Host: lantern.s3.amazonaws.com
        Proxy-Connection: Keep-Alive
        User-Agent: Apache-HttpClient/4.2.2 (java 1.5)
        */
    /*
            "GET http://www.google.com/ HTTP/1.1\r\n"+
            //"GET / HTTP/1.1\r\n"+
            "Host: www.google.com\r\n"+
            "User-Agent: Apache-HttpClient/4.2.2 (java 1.5)\r\n"+
            "Connection: Keep-Alive\r\n\r\n";
            */
    
    private static final String RESPONSE = 
            "HTTP/1.1 200 OK\r\n" +
            "Server: Gnutella\r\n"+
            "Content-type: application/binary\r\n"+
            "Content-Length: 0\r\n" +
            "\r\n";
    
    private void startProxyServer(final int port) throws Exception {
        // We configure the proxy server to always return a cache hit with 
        // the same generic response.
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                final HttpProxyServer server = new DefaultHttpProxyServer(port, 
                    new ProxyCacheManager() {
                    
                    @Override
                    public boolean returnCacheHit(final HttpRequest request, 
                           final Channel channel) {
                        //System.err.println("GOT REQUEST:\n"+request);
                        //channel.write(ChannelBuffers.wrappedBuffer(RESPONSE.getBytes()));
                        //ProxyUtils.closeOnFlush(channel);
                        //return true;
                        return false;
                    }
                    
                    @Override
                    public Future<String> cache(final HttpRequest originalRequest,
                        final org.jboss.netty.handler.codec.http.HttpResponse httpResponse,
                        final Object response, ChannelBuffer encoded) {
                        return null;
                    }
                });
                
                System.out.println("About to start...");
                server.start();
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
    
    /*
    private void hitRelayUdtNetty(final int relayPort, final String expected) 
        throws Exception {
        
        // Configure the client.
        final Bootstrap boot = new Bootstrap();
        final ThreadFactory connectFactory = Threads.newThreadFactory("connect");
        final NioEventLoopGroup connectGroup = new NioEventLoopGroup(1,
                connectFactory, NioUdtProvider.BYTE_PROVIDER);
        
        final AtomicReference<String> responseRef = new AtomicReference<String>("");
        
        //final Channel browserToProxyChannel = new AbstractCh
        final org.jboss.netty.channel.ChannelPipeline pipeline = Channels.pipeline();
        final DummyChannel chan = createDummyChannel(pipeline); 
        try {
            boot.group(connectGroup)
                .channelFactory(NioUdtProvider.BYTE_CONNECTOR)
                .handler(new ChannelInitializer<UdtChannel>() {
                    @Override
                    public void initChannel(final UdtChannel ch)
                            throws Exception {
                        final ChannelPipeline p = ch.pipeline();
                        p.addLast(
                            //new LoggingHandler(LogLevel.INFO),
                            new HttpResponseClientHandler(responseRef, chan));
                    }
                });
            // Start the client.
            final ChannelFuture f = 
                boot.connect(LanternClientConstants.LOCALHOST, relayPort).sync();
            
            synchronized(chan) {
                if (chan.message.length() == 0) {
                    chan.wait(2000);
                }
            }
            
            //System.err.println(chan.message);
            assertTrue("Unexpected response "+responseRef.get(), 
                    chan.message.startsWith("HTTP/1.1 200 OK"));
            
            //assertTrue("Unexpected response "+responseRef.get(), 
            //        responseRef.get().startsWith("HTTP/1.1 200 OK"));
            f.channel().close();
        } finally {
            // Shut down the event loop to terminate all threads.
            boot.shutdown();
        }
    }
    */
    
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
        final FiveTuple ft) throws Exception {
        browserToProxyChannel.setReadable(false);
        
        final Bootstrap boot = new Bootstrap();
        final ThreadFactory connectFactory = Threads.newThreadFactory("connect");
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
                        final SSLEngine engine = TestUtils.getTrustStore().getContext().createSSLEngine();
                        
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
                    browserToProxyChannel.wait(2000);
                }
            }
            
            Thread.sleep(10000);
            
            //System.err.println(chan.message);
            assertTrue("Unexpected response: "+browserToProxyChannel.message, 
                    browserToProxyChannel.message.startsWith("HTTP/1.1 200 OK"));
            // Wait until the connection is closed.
            f.channel().close();
            
        } finally {
            // Shut down the event loop to terminate all threads.
            //boot.shutdown();
        }
    }
    
    private HttpRequest httpRequest;
    
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
    
    
    private void hitRelayUdt(final int relayPort, final String expected) throws Exception {
        final Socket sock = new NetSocketUDT();
        sock.connect(new InetSocketAddress("127.0.0.1", relayPort));
        
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
        
        assertEquals("Response differed: Expected\n"+expected+"\nBut was\n"+response, expected, response);
    }

    private void hitRelayRaw(final int relayPort) throws Exception {
        final Socket sock = new Socket();
        sock.connect(new InetSocketAddress("127.0.0.1", relayPort));
        
        sock.getOutputStream().write(REQUEST.getBytes());
        final BufferedReader br = 
            new BufferedReader(new InputStreamReader(sock.getInputStream()));
        final StringBuilder sb = new StringBuilder();
        String cur = br.readLine();
        sb.append(cur);
        System.err.println(cur);
        while(StringUtils.isNotBlank(cur)) {
            System.err.println(cur);
            cur = br.readLine();
            sb.append(cur);
        }
        assertTrue("Unexpected response "+sb.toString(), sb.toString().startsWith("HTTP/1.1 200 OK"));
        //System.out.println("");
        sock.close();
    }
    
    private void hitRelay(final int relayPort) throws Exception {
        // We create new clients each time here to ensure that we're always
        // using a new client-side port.
        final DefaultHttpClient httpClient = new DefaultHttpClient();
        final HttpHost proxy = new HttpHost("127.0.0.1", relayPort);
        
        httpClient.getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY, proxy);
        httpClient.setHttpRequestRetryHandler(new DefaultHttpRequestRetryHandler(2,true));
        httpClient.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 50000);
        httpClient.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 120000);
        
        //final HttpGet get = new HttpGet("http://www.google.com");
        //final HttpGet get = new HttpGet("https://d3g17h6tzzjzlu.cloudfront.net/windows-x86-jre.tar.gz");
        final HttpGet get = new HttpGet("http://lantern.s3.amazonaws.com/windows-x86-1.7.0_03.tar.gz");
        //final HttpGet get = new HttpGet("http://127.0.0.1");
        final HttpResponse response = httpClient.execute(get);
        final HttpEntity entity = response.getEntity();
        final InputStream is = entity.getContent();
        IOUtils.copy(is, new FileOutputStream(new File("test-windows-x86-jre.tar.gz")));
        //final String body = 
        //    IOUtils.toString(entity.getContent()).toLowerCase();
        EntityUtils.consume(entity);
        //assertTrue(body.trim().endsWith("</script></body></html>"));
        
        get.reset();
    }
    
    private void startRelay(final UdtRelayProxy relay, 
        final int localRelayPort, final boolean udt) throws Exception {
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                try {
                    if (udt) {
                        relay.run();
                    } else {
                        //relay.runTcp();
                        throw new Error("Not running UDT?");
                    }
                } catch (Exception e) {
                    throw new RuntimeException("Error running server", e);
                }
            }
        }, "Relay-Test-Thread");
        t.setDaemon(true);
        t.start();
        if (udt) {
            // Just sleep if it's UDT...
            Thread.sleep(800);
        } else if (!LanternUtils.waitForServer(localRelayPort, 6000)) {
            fail("Could not start relay server!!");
        }
    }

}
