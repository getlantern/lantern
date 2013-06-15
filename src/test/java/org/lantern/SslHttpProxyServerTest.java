package org.lantern;

import static org.junit.Assert.assertTrue;

import java.net.URI;

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
import org.jboss.netty.util.HashedWheelTimer;
import org.junit.Test;
import org.lantern.state.Model;
import org.lantern.util.HttpClientFactory;
import org.littleshoot.proxy.HandshakeHandlerFactory;
import org.littleshoot.proxy.HttpRequestFilter;

public class SslHttpProxyServerTest {

    @Test
    public void test() throws Exception {
        //Launcher.configureCipherSuites();
        //System.setProperty("javax.net.debug", "ssl");
        org.jboss.netty.util.Timer timer = 
            new org.jboss.netty.util.HashedWheelTimer();
        
        final LanternKeyStoreManager ksm = new LanternKeyStoreManager();
        final LanternTrustStore ts = new LanternTrustStore(ksm);
        final String testId = "127.0.0.1";//"test@gmail.com/somejidresource";
        ts.addBase64Cert(new URI(testId), ksm.getBase64Cert(testId));
        final HandshakeHandlerFactory hhf = 
            new CertTrackingSslHandlerFactory(new HashedWheelTimer(), ts);
        final int port = LanternUtils.randomPort();
        final Model model = new Model();
        model.getSettings().setServerPort(port);
        //final PeerFactory peerFactory = new Pee
        //final GlobalLanternServerTrafficShapingHandler trafficHandler =
        //        new GlobalLanternServerTrafficShapingHandler(timer, peerFactory);
        
        final SslHttpProxyServer server = 
            new SslHttpProxyServer(
            new HttpRequestFilter() {
                @Override
                public void filter(HttpRequest httpRequest) {}
            }, 
            new NioClientSocketChannelFactory(), timer,
            new NioServerSocketChannelFactory(), hhf, null,
            model, null);
        
        thread(server);
        
        LanternUtils.waitForServer(server.getPort());
        
        
        final LanternSocketsUtil socketsUtil = 
                new LanternSocketsUtil(null, ts);
        final HttpClientFactory httpFactory =
                new HttpClientFactory(socketsUtil, null, null);
        
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
