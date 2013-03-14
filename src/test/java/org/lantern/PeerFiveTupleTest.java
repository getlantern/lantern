package org.lantern;

import static org.junit.Assert.assertTrue;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.concurrent.atomic.AtomicInteger;

import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

import org.apache.commons.lang.StringUtils;
import org.junit.Test;
import org.lastbamboo.common.offer.answer.IceConfig;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.util.FiveTuple;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.barchart.udt.net.NetSocketUDT;


public class PeerFiveTupleTest {
    
    private final Logger log = LoggerFactory.getLogger(getClass());

    final int messageSize = 64 * 1024;
    
    @Test
    public void testSocket() throws Exception {
        
        //System.setProperty("javax.net.debug", "ssl");
        
        // Note you have to have a remote peer URI that's up a running for
        // this test to work. In the future we'll likely develop a test
        // framework that simulates things like unpredictable network latency
        // and doesn't require live tests over the network.
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
        final String peer = "lanternftw@gmail.com/-lan-147DB73F";
        if (StringUtils.isBlank(peer)) {
            return;
        }
        final URI uri = new URI(peer);

        final Collection<Socket> socks = new ArrayList<Socket>();
        final FiveTuple s = LanternUtils.openOutgoingPeer(uri, 
                xmpp.getP2PClient(), 
            new HashMap<URI, AtomicInteger>());
        
        System.err.println("************************************GOT 5 TUPLE!!!!");
        final InetSocketAddress local = s.getLocal();
        final InetSocketAddress remote = s.getRemote();
        //run(remote.getAddress().getHostAddress(), remote.getPort());
        
        hitRelayUdt(remote, "");
        /*
        final Socket clientSocket = new NetSocketUDTWrapper();
        
        log.info("Binding to address and port");
        clientSocket.bind(new InetSocketAddress(local.getAddress(),
            local.getPort()));

        log.info("About to connect...");
        clientSocket.connect(
            new InetSocketAddress(remote.getAddress(), remote.getPort()));
        
        System.err.println("SOCKET CONNECTED? "+clientSocket.isConnected());
                
        for (final Socket sock : socks) {
            sock.close();
        }
        */
    }
    
    
    private static final String REQUEST =
        "HEAD http://lantern.s3.amazonaws.com/windows-x86-1.7.0_03.tar.gz HTTP/1.1\r\n"+
        "Host: lantern.s3.amazonaws.com\r\n"+
        "Proxy-Connection: Keep-Alive\r\n"+
        "User-Agent: Apache-HttpClient/4.2.2 (java 1.5)\r\n" +
        "\r\n";
    
    private void hitRelayUdt(final InetSocketAddress socketAddress, 
            final String expected) throws Exception {
        final Socket plainText = new NetSocketUDT();
        plainText.connect(socketAddress);
        
        final SSLSocket ssl =
            (SSLSocket)((SSLSocketFactory)TestUtils.getSocketsUtil().newTlsSocketFactory()).createSocket(plainText, 
                    plainText.getInetAddress().getHostAddress(), 
                    plainText.getPort(), true);
        
        final SSLSocket sock = ssl;
        sock.setUseClientMode(true);
        sock.startHandshake();
        
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
        plainText.close();
        assertTrue("Unexpected response "+response, 
            response.startsWith("HTTP/1.1 200 OK"));
    }
}
