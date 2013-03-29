package org.lantern;

import static org.junit.Assert.assertTrue;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.util.EntityUtils;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioServerSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.junit.Test;
import org.lantern.util.HttpClientFactory;
import org.littleshoot.proxy.HandshakeHandlerFactory;
import org.littleshoot.proxy.HttpRequestFilter;

public class SslHttpProxyServerTest {

    @Test
    public void test() throws Exception {
        //Launcher.configureCipherSuites();
        //System.setProperty("javax.net.debug", "ssl");
        //TestUtils.getModel().getPeerCollector().setPeers(new ConcurrentHashMap<String, Peer>());
        //final SslHttpProxyServer server = TestUtils.getSslHttpProxyServer();
        org.jboss.netty.util.Timer timer = 
            new org.jboss.netty.util.HashedWheelTimer();
        
        final LanternKeyStoreManager ksm = new LanternKeyStoreManager();
        final LanternTrustStore ts = new LanternTrustStore(ksm);
        final HandshakeHandlerFactory hhf = 
            new CertTrackingSslHandlerFactory(ksm, ts);
        final int port = LanternUtils.randomPort();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        //final PeerFactory peerFactory = new Pee
        //final GlobalLanternServerTrafficShapingHandler trafficHandler =
        //        new GlobalLanternServerTrafficShapingHandler(timer, peerFactory);
        final SslHttpProxyServer server = 
            new SslHttpProxyServer(port,
            new HttpRequestFilter() {
                @Override
                public void filter(HttpRequest httpRequest) {}
            }, 
            new NioClientSocketChannelFactory(), timer,
            new NioServerSocketChannelFactory(), hhf, null,
            null);
        
        thread(server);
        
        LanternUtils.waitForServer(server.getPort());
        
        final String testId = "127.0.0.1";//"test@gmail.com/somejidresource";
        trustStore.addBase64Cert(testId, ksm.getBase64Cert(testId));
        
        final LanternSocketsUtil socketsUtil = 
                new LanternSocketsUtil(null, trustStore);
        final HttpClientFactory httpFactory =
                new HttpClientFactory(socketsUtil, null);
                //TestUtils.getHttpClientFactory();
        
        final HttpHost host = new HttpHost(
                "127.0.0.1", server.getPort(), "https");
        
        final HttpClient client = httpFactory.newClient(host, true);
        
        final HttpGet get = new HttpGet("https://www.google.com");
        
        final HttpResponse response = client.execute(get);
        final HttpEntity entity = response.getEntity();
        final String body = 
            IOUtils.toString(entity.getContent()).toLowerCase();

        assertTrue("No response?", StringUtils.isNotBlank(body));
        EntityUtils.consume(entity);
        get.reset();
        
        /*
        // We have to wait for the peer geo IP lookup, so keep polling for
        // the peer being added.
        Collection<Peer> peers = TestUtils.getModel().getPeers();
        int tries = 0;
        while (peers.isEmpty() && tries < 60) {
            Thread.sleep(100);
            peers = TestUtils.getModel().getPeers();
            tries++;
        }
        
        assertEquals(1, peers.size());
        
        final Peer peer = peers.iterator().next();
        final LanternTrafficCounter tch = peer.getTrafficCounter();
        
        final long readBytes = tch.getCumulativeReadBytes();
        assertTrue(readBytes > 1000);
        final GlobalLanternServerTrafficShapingHandler traffic = 
                TestUtils.getGlobalTraffic();
        
        // We should have two total sockets because the "waitForServer" call
        // above polls for the socket. At the same time, we only have one
        // total peer because both sockets are from localhost and we 
        // consolidate Peers by address.
        assertEquals(2, traffic.getNumSocketsTotal());
        */
        
    }

    private void thread(final SslHttpProxyServer server) {
        final Runnable runner = new Runnable() {

            @Override
            public void run() {
                server.start(true, true);
            }
        };
        final Thread t = new Thread(runner, "test-tread-"+getClass());
        t.setDaemon(true);
        t.start();
        
    }

}
