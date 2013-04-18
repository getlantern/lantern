package org.lantern;

import static org.junit.Assert.assertEquals;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.StringReader;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.nio.charset.Charset;
import java.util.concurrent.atomic.AtomicBoolean;

import org.apache.commons.httpclient.HttpClient;
import org.apache.commons.httpclient.HttpMethod;
import org.apache.commons.httpclient.HttpStatus;
import org.apache.commons.httpclient.methods.GetMethod;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.junit.Test;
import org.lastbamboo.common.amazon.ec2.AmazonEc2Utils;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.littleshoot.util.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class UpnpTest {
    private final Logger log = LoggerFactory.getLogger(getClass());

    @Test
    public void testUpnp() throws Exception {
        final InetAddress lh = NetworkUtils.getLocalHost();
        final String local = lh.getHostAddress();
        if (lh.getHostName().startsWith("domU-") || local.startsWith("10.191") || 
                local.startsWith("10.84") || local.startsWith("10.112") || AmazonEc2Utils.onEc2()) {
            log.debug("Ingoring test on EC2");
            return;
        }
        log.debug("Local host name is: {}", NetworkUtils.getLocalHost().getHostName());
        //System.setProperty("java.util.logging.config.file",
        //        "src/test/resources/logging.properties");
        final Upnp up = new Upnp(TestUtils.getStatsTracker());
        final AtomicBoolean mapped = new AtomicBoolean(false);
        final AtomicBoolean error = new AtomicBoolean(false);

        final PortMapListener pml = new PortMapListener() {
            @Override
            public void onPortMapError() {
                synchronized (mapped) {
                    mapped.notifyAll();
                }
            }

            @Override
            public void onPortMap(final int port) {
                log.info("Got port mapped: " + port);
                mapped.set(true);
                synchronized (mapped) {
                    mapped.notifyAll();
                }
            }
        };
        int port = 25516;
        up.addUpnpMapping(PortMappingProtocol.TCP, port, port, pml);

        synchronized (mapped) {
            if (!mapped.get()) {
                mapped.wait(10000);
            }
        }

        if (!mapped.get()) {
            log.debug("Network does not seem to support UPNP so we're not testing it.");
            return;
        }

        String ip = up.getPublicIpAddress();
        if (StringUtils.isBlank(ip)) {
            log.warn("NO PUBLIC IP FROM ROUTER!! DOUBLE NATTED?");
            return;
            //ip = new PublicIpAddress().getPublicIpAddress().getHostAddress();
        }

        // Set up a local HTTP server on the local port, so that we can check
        // said port from the outside.
        TestHttpServer testHttpServer = new TestHttpServer(port);
        HttpClient client = new HttpClient();
        String url = "http://upnptest.getlantern.org/cgi-bin/callback.py?ip="
                + ip + "&port=" + port;
        System.out.println("Requesting callback from " + url);
        HttpMethod method = new GetMethod(url);
        try {
            testHttpServer.start();
            int statusCode = client.executeMethod(method);
            if (statusCode != HttpStatus.SC_OK) {
                System.err.println("Method failed: " + method.getStatusLine());
            }
            // throw away body
            method.getResponseBody();

            assertEquals(1, testHttpServer.getRequests());
            System.out.println("Got callback, port mapping is open");
        } finally {
            method.releaseConnection();
            testHttpServer.stopServer();
        }

        // We might not be running on a router that supports UPnP
        if (!error.get()) {
            // We don't necessarily get an error even if the router doesn't
            // support UPnP.
            // assertTrue(mapped.get());
        }
    }
}

class TestHttpServer extends Thread {
    ServerSocket socket;
    private int requests = 0;
    private boolean running = true;

    TestHttpServer(int port) {
        try {
            socket = new ServerSocket(port);
            socket.setSoTimeout(1000);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    public void run() {
        while (running) {
            try {
                Socket incoming = socket.accept();
                OutputStream oStream = incoming.getOutputStream();
                InputStream iStream = incoming.getInputStream();
                iStream.read(new byte[4096]);

                // ignore request; send response
                StringReader reader = new StringReader(
                        "Content-Type:text/html\n\nOK\n");
                IOUtils.copy(reader, oStream, Charset.forName("ASCII"));
                oStream.flush();
                incoming.close();
                requests++;
            } catch (SocketTimeoutException e) {
                continue;
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }
    }

    public void stopServer() {
        running = false;
    }

    public int getRequests() {
        return requests;
    }
}