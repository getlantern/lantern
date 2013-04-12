package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.File;
import java.io.FileInputStream;
import java.net.InetSocketAddress;
import java.net.SocketAddress;
import java.net.URI;
import java.util.concurrent.Executors;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.AbstractChannel;
import org.jboss.netty.channel.AbstractChannelSink;
import org.jboss.netty.channel.ChannelConfig;
import org.jboss.netty.channel.ChannelEvent;
import org.jboss.netty.channel.ChannelPipelineException;
import org.jboss.netty.channel.ChannelSink;
import org.jboss.netty.channel.Channels;
import org.jboss.netty.channel.DefaultChannelConfig;
import org.jboss.netty.channel.group.DefaultChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.ServerSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioServerSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpVersion;
import org.jboss.netty.util.HashedWheelTimer;
import org.junit.Test;
import org.lantern.state.Peer;
import org.lantern.state.Peer.Type;
import org.lantern.util.GlobalLanternServerTrafficShapingHandler;
import org.lantern.util.LanternTrafficCounter;
import org.littleshoot.proxy.DefaultHttpProxyServer;
import org.littleshoot.proxy.HandshakeHandlerFactory;
import org.littleshoot.proxy.HttpFilter;
import org.littleshoot.proxy.HttpResponseFilters;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.FiveTuple.Protocol;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.util.concurrent.ThreadFactoryBuilder;

public class TcpHttpRequestProcessorTest {

    private final static Logger log = 
        LoggerFactory.getLogger(TcpHttpRequestProcessorTest.class);
    
    @Test
    public void test() throws Exception {
        // The idea here is to start an HTTP proxy server locally that the UDT
        // relay relays to -- i.e. just like the real world setup.
        
        
        Launcher.configureCipherSuites();
        
        final LanternKeyStoreManager ksm = new LanternKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);

        final String dummyId = "test@gmail.com/-lan-22LJDEE";
        trustStore.addBase64Cert(new URI(dummyId), ksm.getBase64Cert(dummyId));
        
        final HandshakeHandlerFactory hhf = 
            new CertTrackingSslHandlerFactory(new HashedWheelTimer(), trustStore);
        final PeerFactory peerFactory = new PeerFactory() {

            @Override
            public void onOutgoingConnection(URI fullJid,
                    InetSocketAddress isa, Type type,
                    LanternTrafficCounter trafficCounter) {
                log.debug("GOT OUTGOING CONNECTION EVENT!!");
            }

            @Override
            public Peer addPeer(URI fullJid, Type type) {
                log.debug("Adding peer!!");
                return null;
            }


        };
        
        // Note that an internet connection is required to run this test.
        final int proxyPort = LanternUtils.randomPort();
        //final int relayPort = LanternUtils.randomPort();
        startProxyServer(proxyPort, hhf, true, peerFactory);
        final InetSocketAddress localProxyAddress = 
            new InetSocketAddress(LanternClientConstants.LOCALHOST, proxyPort);
        
        
        
        // Hit the proxy directly first so we can verify we get the exact
        // same thing (except a few specific HTTP headers) from the relay.
        //final String expected = hitProxyDirect(proxyPort);
        
        // We do this a few times to make sure there are no issues with 
        // subsequent runs.
        
        for (int i = 0; i < 1; i++) {
            final String uri = 
                //"http://lantern.s3.amazonaws.com/windows-x86-1.7.0_03.tar.gz";
                "http://lantern.s3.amazonaws.com/testFile.txt ";
            final HttpRequest request = 
                new org.jboss.netty.handler.codec.http.DefaultHttpRequest(
                    HttpVersion.HTTP_1_1, HttpMethod.GET, uri);
            
            request.addHeader("Host", "lantern.s3.amazonaws.com");
            request.addHeader("Proxy-Connection", "Keep-Alive");
            testRequestProcessing(createDummyChannel(), request, 
                new FiveTuple(null, localProxyAddress, Protocol.TCP), trustStore);
        }
       
        /*
        for (int i = 0; i < 1; i++) {
            final String uri = 
                //"http://lantern.s3.amazonaws.com/windows-x86-1.7.0_03.tar.gz";
                "http://lantern.s3.amazonaws.com/testFile.txt ";
            final HttpRequest request = 
                new org.jboss.netty.handler.codec.http.DefaultHttpRequest(
                    HttpVersion.HTTP_1_1, HttpMethod.CONNECT, uri);
            
            //request.addHeader("Host", "lantern.s3.amazonaws.com");
            //request.addHeader("Proxy-Connection", "Keep-Alive");
            testRequestProcessing(createDummyChannel(), request, 
                new FiveTuple(null, localRelayAddress, Protocol.TCP), ksm);
        }
         */
    }
    
    private void startProxyServer(final int port, 
        final HandshakeHandlerFactory hhf, final boolean ssl,
        final PeerFactory peerFactory) throws Exception {
        // We configure the proxy server to always return a cache hit with 
        // the same generic response.
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                if (ssl) {
                    final org.jboss.netty.util.Timer timer = 
                        new org.jboss.netty.util.HashedWheelTimer();
                    final HttpProxyServer server = 
                        new StatsTrackingDefaultHttpProxyServer(port,
                        new HttpResponseFilters() {
                            @Override
                            public HttpFilter getFilter(String arg0) {
                                return null;
                            }
                        }, null, null,
                        provideClientSocketChannelFactory(), timer,
                        provideServerSocketChannelFactory(), hhf, null,
                        new GlobalLanternServerTrafficShapingHandler(timer));
                    try {
                        server.start();
                        log.debug("SSL proxy server started");
                    } catch (final Exception e) {
                        log.error("Error starting server!!", e);
                    }
                } else {
                    final org.littleshoot.proxy.HttpProxyServer server =
                            new DefaultHttpProxyServer(port);
                    try {
                        server.start();
                        log.debug("Proxy server started");
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
    
    ServerSocketChannelFactory provideServerSocketChannelFactory() {
        return new NioServerSocketChannelFactory(
            Executors.newCachedThreadPool(
                new ThreadFactoryBuilder().setNameFormat(
                    "Lantern-Netty-Server-Boss-Thread-%d").setDaemon(true).build()),
            Executors.newCachedThreadPool(
                new ThreadFactoryBuilder().setNameFormat(
                    "Lantern-Netty-Server-Worker-Thread-%d").setDaemon(true).build()));
    }
    
    ClientSocketChannelFactory provideClientSocketChannelFactory() {
        return new NioClientSocketChannelFactory(
            Executors.newCachedThreadPool(
                new ThreadFactoryBuilder().setNameFormat(
                    "Lantern-Netty-Client-Boss-Thread-%d").setDaemon(true).build()),
            Executors.newCachedThreadPool(
                new ThreadFactoryBuilder().setNameFormat(
                    "Lantern-Netty-Client-Worker-Thread-%d").setDaemon(true).build()));
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
            //log.debug("Got message on dummy client channel..");
            this.message += msg;
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
    
    private void testRequestProcessing(
        final DummyChannel browserToProxyChannel, final HttpRequest request,
        final FiveTuple ft, final LanternTrustStore trustStore) throws Exception {
        // First we need the proxy tracker to 
 
        final ProxyTracker proxyTracker = newProxyTracker(ft);

        final TcpHttpRequestProcessor processor =
            new TcpHttpRequestProcessor(proxyTracker,
                new NioClientSocketChannelFactory(),
                new DefaultChannelGroup("Test-Group"), null, trustStore);
        
        final boolean processed = 
            processor.processRequest(browserToProxyChannel, null, request);
        
        assertTrue("Could not process request?", processed);
        int count = 0;
        while (browserToProxyChannel.message.length() < 40000 && count < 100) {
            Thread.sleep(100);
            count++;
        }
        
        assertTrue("Unexpected response: "+browserToProxyChannel.message, 
                browserToProxyChannel.message.startsWith("HTTP/1.1 200 OK"));
        
        // Now check the body:
        final String body = 
            StringUtils.substringAfter(browserToProxyChannel.message, "\r\n\r\n");
        assertEquals("Unexpected body length: "+body.length(), 40129, body.length());
        final File test = new File("src/test/resources/testFile.txt");
        assertEquals(IOUtils.toString(new FileInputStream(test)), body);
    }
    private ProxyTracker newProxyTracker(final FiveTuple ft) {
        return new ProxyTracker() {
            @Override
            public void stop() {}
            @Override
            public void start() throws Exception {}
            @Override
            public boolean hasProxy() {return true;}
            @Override
            public ProxyHolder getProxy() {return new ProxyHolder("", null, ft, null, Type.pc);}
            @Override
            public ProxyHolder getLaeProxy() {return null;}
            @Override
            public ProxyHolder getJidProxy() {return new ProxyHolder("", null, ft, null, Type.pc);}
            @Override
            public void onError(URI peerUri) {}
            @Override
            public void onCouldNotConnectToPeer(URI peerUri) {}
            @Override
            public void onCouldNotConnectToLae(ProxyHolder proxyAddress) {}
            @Override
            public void onCouldNotConnect(ProxyHolder proxyAddress) {}
            @Override
            public void removePeer(URI uri) {}
            @Override
            public boolean isEmpty() {return false;}
            @Override
            public boolean hasJidProxy(URI uri) {return false;}
            @Override
            public void clearPeerProxySet() {}
            @Override
            public void clear() {}
            @Override
            public void addLaeProxy(String cur) {}
            @Override
            public void addJidProxy(URI jid) {}
            @Override
            public void addProxy(URI jid, String hostPort) {}
            @Override
            public void addProxy(URI jid, InetSocketAddress iae) {}
            @Override
            public void setSuccess(ProxyHolder proxyHolder) {}
        };
    }
}
