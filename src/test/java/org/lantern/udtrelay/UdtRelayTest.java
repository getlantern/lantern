package org.lantern.udtrelay;

import static org.junit.Assert.assertTrue;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.fail;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.concurrent.Future;

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
import org.jboss.netty.channel.Channel;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.junit.Test;
import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.littleshoot.proxy.DefaultHttpProxyServer;
import org.littleshoot.proxy.HttpProxyServer;
import org.littleshoot.proxy.ProxyCacheManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.barchart.udt.net.NetSocketUDT;

public class UdtRelayTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
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
            new UdtRelayProxy(localRelayAddress.getPort(), proxyPort);
        startRelay(relay, localRelayAddress.getPort(), udt);
        
        final String expected = hitProxyDirect(proxyPort);
        
        // We do this a few times to make sure there are no issues with 
        // subsequent runs.
        for (int i = 0; i < 3; i++) {
            //hitRelay(proxyPort);
            
            if (udt) {
                hitRelayUdt(relayPort, expected);
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
        //int count = 0;
        while(StringUtils.isNotBlank(cur)) {// && count < 6) {
            System.err.println(cur);
            cur = br.readLine();
            if (!cur.startsWith("x-amz-") && !cur.startsWith("Date")) {
                sb.append(cur);
                sb.append("\n");
            }
            //count++;
        }
        final String response = sb.toString();
        sock.close();
        assertTrue("Unexpected response "+response, 
            response.startsWith("HTTP/1.1 200 OK"));

        return response;

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
        //int count = 0;
        while(StringUtils.isNotBlank(cur)) {// && count < 6) {
            System.err.println(cur);
            cur = br.readLine();
            if (!cur.startsWith("x-amz-") && !cur.startsWith("Date")) {
                sb.append(cur);
                sb.append("\n");
            }
            //count++;
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
        
        
        //IOUtils.copy(sock.getInputStream(), new FileOutputStream(new File("test-windows-x86-jre.tar.gz")));
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

}
