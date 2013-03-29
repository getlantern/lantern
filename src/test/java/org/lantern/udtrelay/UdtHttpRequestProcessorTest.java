package org.lantern.udtrelay;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.File;
import java.io.FileInputStream;
import java.net.InetSocketAddress;
import java.net.SocketAddress;
import java.net.URI;

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
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioServerSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpMethod;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.jboss.netty.handler.codec.http.HttpVersion;
import org.junit.Test;
import org.lantern.CertTrackingSslHandlerFactory;
import org.lantern.HttpProxyServer;
import org.lantern.LanternClientConstants;
import org.lantern.LanternConstants;
import org.lantern.LanternKeyStoreManager;
import org.lantern.LanternTrustStore;
import org.lantern.LanternUtils;
import org.lantern.Launcher;
import org.lantern.ProxyHolder;
import org.lantern.ProxyTracker;
import org.lantern.StatsTrackingDefaultHttpProxyServer;
import org.lantern.UdtHttpRequestProcessor;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.littleshoot.proxy.DefaultHttpProxyServer;
import org.littleshoot.proxy.HandshakeHandlerFactory;
import org.littleshoot.proxy.HttpFilter;
import org.littleshoot.proxy.HttpResponseFilters;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.FiveTuple.Protocol;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class UdtHttpRequestProcessorTest {

    private final static Logger log = 
        LoggerFactory.getLogger(UdtHttpRequestProcessorTest.class);
    
    @Test
    public void test() throws Exception {
        // The idea here is to start an HTTP proxy server locally that the UDT
        // relay relays to -- i.e. just like the real world setup.
        
        final boolean udt = true;
        
        IceConfig.setDisableUdpOnLocalNetwork(false);
        IceConfig.setTcp(false);
        Launcher.configureCipherSuites();
        
        final LanternKeyStoreManager ksm = new LanternKeyStoreManager();
        final LanternTrustStore ts = new LanternTrustStore(ksm);
        final HandshakeHandlerFactory hhf = 
                new CertTrackingSslHandlerFactory(ksm, ts);
        
        // Note that an internet connection is required to run this test.
        final int proxyPort = LanternUtils.randomPort();
        final int relayPort = LanternUtils.randomPort();
        startProxyServer(proxyPort, hhf, true);
        final InetSocketAddress localRelayAddress = 
            new InetSocketAddress(LanternClientConstants.LOCALHOST, relayPort);
        
        
        final UdtRelayProxy relay = 
            new UdtRelayProxy(localRelayAddress, proxyPort);
        startRelay(relay, localRelayAddress.getPort(), udt);
        
        
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
                new FiveTuple(null, localRelayAddress, Protocol.TCP), ksm);
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
        final HandshakeHandlerFactory ksm, final boolean ssl) throws Exception {
        // We configure the proxy server to always return a cache hit with 
        // the same generic response.
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                if (ssl) {
                    org.jboss.netty.util.Timer timer = 
                        new org.jboss.netty.util.HashedWheelTimer();
                    final HttpProxyServer server = 
                        new StatsTrackingDefaultHttpProxyServer(port,
                        new HttpResponseFilters() {
                            @Override
                            public HttpFilter getFilter(String arg0) {
                                return null;
                            }
                        }, null, null,
                        new NioClientSocketChannelFactory(), timer,
                        new NioServerSocketChannelFactory(), ksm, null,
                        null);
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
        final FiveTuple ft, final LanternKeyStoreManager ksm) throws Exception {
        // First we need the proxy tracker to 
 
        final ProxyTracker proxyTracker = newProxyTracker(ft);
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        final String dummyId = "test@gmail.com/-lan-22LJDEE";
        trustStore.addBase64Cert(dummyId, ksm.getBase64Cert(dummyId));
        final UdtHttpRequestProcessor processor =
                new UdtHttpRequestProcessor(proxyTracker, null, null, 
                    trustStore);
        
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
    
    private void startRelay(final UdtRelayProxy relay, 
        final int localRelayPort, final boolean udt) throws Exception {
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                try {
                    if (udt) {
                        relay.run();
                    } else {
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
            //Thread.sleep(800);
            Thread.yield();
        } else if (!LanternUtils.waitForServer(localRelayPort, 6000)) {
            fail("Could not start relay server!!");
        }
    }


    private ProxyTracker newProxyTracker(final FiveTuple ft) {
        return new ProxyTracker() {
            
            @Override
            public void stop() {}
            
            @Override
            public void start() throws Exception {}
            
            @Override
            public boolean hasProxy() {
                return false;
            }
            
            @Override
            public ProxyHolder getProxy() {
                return null;
            }
            
            @Override
            public ProxyHolder getLaeProxy() {
                return null;
            }
            
            @Override
            public ProxyHolder getJidProxy() {
                return new ProxyHolder("", ft, null);
            }
            
            @Override
            public void onError(URI peerUri) {
            }
            
            @Override
            public void onCouldNotConnectToPeer(URI peerUri) {
            }
            
            @Override
            public void onCouldNotConnectToLae(ProxyHolder proxyAddress) {
            }
            
            @Override
            public void onCouldNotConnect(ProxyHolder proxyAddress) {
            }
            
            @Override
            public void removePeer(URI uri) {
            }
            
            @Override
            public boolean isEmpty() {
                return false;
            }
            
            @Override
            public boolean hasJidProxy(URI uri) {
                return false;
            }
            
            @Override
            public void clearPeerProxySet() {
            }
            
            @Override
            public void clear() {
                
            }
            
            @Override
            public void addProxy(InetSocketAddress iae) {
                
            }
            
            @Override
            public void addProxy(String hostPort) {
            }
            
            @Override
            public void addLaeProxy(String cur) {
            }
            
            @Override
            public void addJidProxy(URI jid) {
            }
        };
    }
}
