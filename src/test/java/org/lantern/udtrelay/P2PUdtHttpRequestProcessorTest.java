package org.lantern.udtrelay;

import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.net.InetSocketAddress;
import java.net.SocketAddress;
import java.net.URI;
import java.util.concurrent.Future;

import org.jboss.netty.buffer.ChannelBuffer;
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
import org.jboss.netty.handler.codec.http.HttpVersion;
import org.junit.Test;
import org.lantern.LanternClientConstants;
import org.lantern.LanternConstants;
import org.lantern.LanternTrustStore;
import org.lantern.LanternUtils;
import org.lantern.Launcher;
import org.lantern.P2PUdtHttpRequestProcessor;
import org.lantern.ProxyHolder;
import org.lantern.ProxyTracker;
import org.lantern.TestUtils;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.littleshoot.proxy.DefaultHttpProxyServer;
import org.littleshoot.proxy.HttpProxyServer;
import org.littleshoot.proxy.ProxyCacheManager;
import org.littleshoot.util.FiveTuple;
import org.littleshoot.util.FiveTuple.Protocol;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class P2PUdtHttpRequestProcessorTest {

    private final static Logger log = 
        LoggerFactory.getLogger(P2PUdtHttpRequestProcessorTest.class);
    
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
        
        // We do this a few times to make sure there are no issues with 
        // subsequent runs.
        for (int i = 0; i < 1; i++) {
            final String uri = "http://lantern.s3.amazonaws.com/windows-x86-1.7.0_03.tar.gz";
            final HttpRequest request = 
                new org.jboss.netty.handler.codec.http.DefaultHttpRequest(
                    HttpVersion.HTTP_1_1, HttpMethod.HEAD, uri);
            
            request.addHeader("Host", "lantern.s3.amazonaws.com");
            request.addHeader("Proxy-Connection", "Keep-Alive");
            testRequestProcessing(createDummyChannel(), request, 
                new FiveTuple(null, localRelayAddress, Protocol.TCP));
        }
    }
    
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
    
    private void testRequestProcessing(
        final DummyChannel browserToProxyChannel, final HttpRequest request,
        final FiveTuple ft) throws Exception {
        // First we need the proxy tracker to 
 
        final ProxyTracker proxyTracker = newProxyTracker(ft);
        final LanternTrustStore trustStore = TestUtils.buildTrustStore();
        final P2PUdtHttpRequestProcessor processor =
                new P2PUdtHttpRequestProcessor(proxyTracker, null, null, null, 
                    trustStore);
        
        final boolean processed = 
            processor.processRequest(browserToProxyChannel, null, request);
        
        assertTrue("Could not process request?", processed);
        int count = 0;
        while (browserToProxyChannel.message.length() == 0 && count < 100) {
            Thread.sleep(100);
            count++;
        }
        
        //Thread.sleep(10000);
        
        //System.err.println(chan.message);
        assertTrue("Unexpected response: "+browserToProxyChannel.message, 
                browserToProxyChannel.message.startsWith("HTTP/1.1 200 OK"));
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
                        relay.runTcp();
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


    private ProxyTracker newProxyTracker(final FiveTuple ft) {
        return new ProxyTracker() {
            
            @Override
            public void stop() {
                // TODO Auto-generated method stub
                
            }
            
            @Override
            public void start() throws Exception {
                // TODO Auto-generated method stub
                
            }
            
            @Override
            public boolean hasProxy() {
                // TODO Auto-generated method stub
                return false;
            }
            
            @Override
            public ProxyHolder getProxy() {
                // TODO Auto-generated method stub
                return null;
            }
            
            @Override
            public ProxyHolder getLaeProxy() {
                // TODO Auto-generated method stub
                return null;
            }
            
            @Override
            public ProxyHolder getJidProxy() {
                return new ProxyHolder("", ft, null);
            }
            
            @Override
            public void onError(URI peerUri) {
                // TODO Auto-generated method stub
                
            }
            
            @Override
            public void onCouldNotConnectToPeer(URI peerUri) {
                // TODO Auto-generated method stub
                
            }
            
            @Override
            public void onCouldNotConnectToLae(ProxyHolder proxyAddress) {
                // TODO Auto-generated method stub
                
            }
            
            @Override
            public void onCouldNotConnect(ProxyHolder proxyAddress) {
                // TODO Auto-generated method stub
                
            }
            
            @Override
            public void removePeer(URI uri) {
                // TODO Auto-generated method stub
                
            }
            
            @Override
            public boolean isEmpty() {
                // TODO Auto-generated method stub
                return false;
            }
            
            @Override
            public boolean hasJidProxy(URI uri) {
                // TODO Auto-generated method stub
                return false;
            }
            
            @Override
            public void clearPeerProxySet() {
                // TODO Auto-generated method stub
                
            }
            
            @Override
            public void clear() {
                // TODO Auto-generated method stub
                
            }
            
            @Override
            public void addProxy(InetSocketAddress iae) {
                // TODO Auto-generated method stub
                
            }
            
            @Override
            public void addProxy(String hostPort) {
                // TODO Auto-generated method stub
                
            }
            
            @Override
            public void addLaeProxy(String cur) {
                // TODO Auto-generated method stub
                
            }
            
            @Override
            public void addJidProxy(URI jid) {
                // TODO Auto-generated method stub
                
            }
        };
    }
}
