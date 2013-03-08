package org.lantern.udtrelay;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.Test;
import org.lantern.LanternUtils;
import org.lantern.udtrelay.UdtRelayProxy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class UdtRelayTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final byte[] clientRequest = "jfdadlf98314719ufaijfatour89pq;a".getBytes();
    private final byte[] serverResponse = "fajquoqpjf;fmvadva".getBytes();
    
    @Test
    public void test() throws Exception {
        
        // So here's the concept: we basically get NAT-traversed 5 tuples from
        // the p2p layer, where the 5 tuples are the bound and NAT/firewall
        // traversed IP and port for both the "client" and "server" sides of
        // the connection and where the 5th element is the transport (UDT or 
        // TCP). We basically need to dynamically generate a server that
        // will just take in whatever comes in on the server side of that 
        // connection and will relay it to our actual local server. 
        
        // There two reasons we do all this relaying:
        
        // 1) Because in our case that incoming data is actually over a UDT
        // connection, so we need the intermediary server to be able to read
        // in data for that server. 
        // 
        // 2) So that the actual proxy server can just treat it as 
        // another normal incoming socket.
        final AtomicReference<Socket> sockRef = new AtomicReference<Socket>();
        final int destinationServerPort = LanternUtils.randomPort();
        final InetSocketAddress isa = 
                new InetSocketAddress("127.0.0.1", destinationServerPort);
        
        final AtomicReference<byte[]> relayedRequest = new AtomicReference<byte[]>();
        startDestinationServer(isa, sockRef, relayedRequest);
        log.debug("Destination proxy started!!");
        
        //final int localRelayPort = LanternUtils.randomPort();
        final InetSocketAddress localRelayAddress = 
            new InetSocketAddress("127.0.0.1", LanternUtils.randomPort());
        final UdtRelayProxy relay = 
            new UdtRelayProxy(localRelayAddress.getPort(), "127.0.0.1", destinationServerPort);
        startRelay(relay, localRelayAddress.getPort());
        System.err.println("Relay started!!");
        
        // Now we need to connect to the relay and make sure it relays!
        // This will be over UDT.
        final Socket client = new Socket();
        client.connect(localRelayAddress, 3000);
        //final SocketChannel channel = client.getChannel();
        //channel.connect(localRelayAddress);
        
        // First just wait to make sure we get the socket on the server side.
        synchronized (sockRef) {
            if (sockRef.get() == null) {
                sockRef.wait(2000);
            }
        }
        assertTrue(sockRef.get() != null);
        
        final OutputStream os = client.getOutputStream();
        os.write(clientRequest);
        os.flush();
        //os.close();
        log.debug("Flushed client request data to socket");
        
        synchronized (relayedRequest) {
            if (relayedRequest.get() == null) {
                relayedRequest.wait(2000);
            }
        }
        assertEquals("Request not relayed correctly?", 
            new String(clientRequest), new String(relayedRequest.get()));
        
        final InputStream is = client.getInputStream();
        final byte[] response = new byte[serverResponse.length];
        final int read = is.read(response);
        assertEquals(response.length, read);
        
        assertEquals(new String(serverResponse), new String(response));
        
        log.debug("Closing socket at end of test...");
        client.close();
    }

    private void startDestinationServer(final InetSocketAddress sa, 
        final AtomicReference<Socket> sockRef,
        final AtomicReference<byte[]> relayedRequest) throws Exception {
        final ServerSocket ss = new ServerSocket();
        ss.bind(sa);
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                try {
                    final Socket fromPortCheck = ss.accept();
                    log.debug("GOT THROWAWAY SOCK FROM: "+
                            fromPortCheck.getRemoteSocketAddress());
                    // The first socket here is just from our utility code
                    // that waits for the server to be up -- we just ignore 
                    // this one!
                    //fromPortCheck.close();
                    
                    // A second socket comes in again related to our socket 
                    // waiting utility, but this time for a more complicated
                    // reason -- basically when we check for the second, relay
                    // server being up on its port, that incoming connection to
                    // that socket automatically creates an incoming connection
                    // to this server (as it should because its entire purpose
                    // is relaying!). Here, though, that's just another 
                    // incoming socket we should ignore.
                    final Socket fromInit = ss.accept();
                    log.debug("GOT THROWAWAY SOCK FROM: "+fromInit.getRemoteSocketAddress());
                    //fromInit.close();
                    
                    final Socket sock = ss.accept();
                    log.debug("GOT REAL SOCK FROM: "+sock.getRemoteSocketAddress());
                    sockRef.set(sock);
                    synchronized (sockRef) {
                        sockRef.notifyAll();
                    }
                    log.debug("Getting socket input stream...");
                    final InputStream is = sock.getInputStream();
                    log.debug("Got input stream from socket...");
                    /*
                    final StringBuilder sb = new StringBuilder();
                    int bytesRead = 0;
                    while (bytesRead < clientRequest.length) {
                        final int cur = is.read();
                        //log.debug("Read byte: {}", (char)cur);
                        sb.append((char)cur);
                        bytesRead++;
                        log.debug("Full read: {}", sb.toString());
                    }
                    */
                    final byte[] readBytes = new byte[clientRequest.length];
                    log.debug("About to read request from socket...");
                    final long read = is.read(readBytes);
                    log.debug("Read request from socket!!");
                    if (read != clientRequest.length) {
                        throw new RuntimeException("READ "+read+" BYTES NOT "+
                                clientRequest.length);
                    }
                    synchronized (relayedRequest) {
                        relayedRequest.set(readBytes);
                        relayedRequest.notifyAll();
                    }
                    
                    final OutputStream os = sock.getOutputStream();
                    os.write(serverResponse);
                    os.flush();
                    log.debug("Flushed server response from destination server");
                    //sock.close();
                    //ss.close();
                } catch (final IOException e) {
                    throw new RuntimeException("Could not accept socket!", e);
                }
            }
        }, "Test-Proxy-Thread");
        t.setDaemon(true);
        t.start();
        LanternUtils.waitForServer(sa.getPort(), 6000);
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
