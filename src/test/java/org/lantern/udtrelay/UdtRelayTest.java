package org.lantern.udtrelay;

import static org.junit.Assert.assertTrue;

import java.net.InetSocketAddress;

import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.impl.client.DefaultHttpRequestRetryHandler;
import org.apache.http.params.CoreConnectionPNames;
import org.apache.http.util.EntityUtils;
import org.junit.Test;
import org.lantern.LanternUtils;
import org.littleshoot.proxy.DefaultHttpProxyServer;
import org.littleshoot.proxy.HttpProxyServer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class UdtRelayTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Test
    public void test() throws Exception {
        // The idea here is to start an HTTP proxy server locally that the UDT
        // relay relays to -- i.e. just like the real world setup.
        
        // Note that an internet connection is required to run this test.
        final int proxyPort = LanternUtils.randomPort();
        final int relayPort = LanternUtils.randomPort();
        startProxyServer(proxyPort);
        final InetSocketAddress localRelayAddress = 
            new InetSocketAddress("127.0.0.1", relayPort);
        final UdtRelayProxy relay = 
            new UdtRelayProxy(localRelayAddress.getPort(), "127.0.0.1", proxyPort);
        startRelay(relay, localRelayAddress.getPort());
        
        // We do this a few times to make sure there are no issues with 
        // subsequent runs.
        for (int i = 0; i < 3; i++) {
            hitRelay(relayPort);
        }
    }
    
    private void startProxyServer(final int port) throws Exception {
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                final HttpProxyServer server = new DefaultHttpProxyServer(port);
                System.out.println("About to start...");
                server.start();
            }
        }, "Relay-Test-Thread");
        t.setDaemon(true);
        t.start();
        LanternUtils.waitForServer(port, 6000);
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
        
        final HttpGet get = new HttpGet("http://www.google.com");
        final HttpResponse response = httpClient.execute(get);
        final HttpEntity entity = response.getEntity();
        final String body = 
            IOUtils.toString(entity.getContent()).toLowerCase();
        EntityUtils.consume(entity);
        assertTrue(body.trim().endsWith("</script></body></html>"));
        
        get.reset();
    }
    
    private void startRelay(final UdtRelayProxy relay, 
        final int localRelayPort) throws Exception {
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
        LanternUtils.waitForServer(localRelayPort, 6000);
    }

}
