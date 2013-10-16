package org.lantern;

import static org.junit.Assert.assertEquals;

import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.URI;
import java.util.concurrent.atomic.AtomicReference;

import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

import org.apache.commons.lang.StringUtils;
import org.junit.Test;
import org.lastbamboo.common.ice.NetSocketUDTWrapper;

import udt.UDTReceiver;

import com.barchart.udt.net.NetServerSocketUDT;


public class UdtSslTest {

    private static final int SERVER_PORT = 8539;
    private static final int CLIENT_PORT = 8511;
    
    private final AtomicReference<String> readOnServer = 
        new AtomicReference<String>("");
    
    private final String msg = "testing";
    
    private static final int COUNT = 200;
    
    @Test
    public void testSslOverUdt() throws Exception {
        //System.setProperty("javax.net.debug", "ssl");
        final LanternKeyStoreManager ksm = TestingUtils.newKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        
        //final LanternKeyStoreManager ksm = TestUtils.getKsm();
        //final LanternTrustStore trustStore = TestUtils.getTrustStore();
        final String testId = "test@gmail.com/test";
        trustStore.addCert(new URI(testId), LanternUtils.certFromBase64(ksm.getBase64Cert(testId)));
        
        final LanternSocketsUtil util = new LanternSocketsUtil(null, trustStore);
        
        startServer(util);
        ///LanternUtils.waitForServer(SERVER_PORT);
        Thread.sleep(800);
        
        UDTReceiver.connectionExpiryDisabled = true;
        
        final InetAddress myHost = InetAddress.getByName("127.0.0.1");
        //final UDTClient client = new UDTClient(myHost, CLIENT_PORT);
        //client.connect(myHost, SERVER_PORT);
        
        final Socket sock = new NetSocketUDTWrapper();
        sock.bind(new InetSocketAddress(myHost, CLIENT_PORT));
        sock.connect(new InetSocketAddress(myHost, SERVER_PORT));
        
        //final Socket sock = client.getSocket();
        //final Socket sock = new Socket(myHost, SERVER_PORT);
        
        final SSLSocketFactory sslSocketFactory = 
                util.newTlsSocketFactoryJavaCipherSuites();
            //(SSLSocketFactory)SSLSocketFactory.getDefault();
        final SSLSocket sslSocket =
            (SSLSocket)sslSocketFactory.createSocket(sock, 
                sock.getInetAddress().getHostAddress(), sock.getPort(), false);
                //"127.0.0.1", sock.getPort(), false);
        sslSocket.setUseClientMode(true);
        sslSocket.startHandshake();
        
        final StringBuilder expected = new StringBuilder();
        synchronized (readOnServer) {
            final OutputStream os = sslSocket.getOutputStream();
            for (int i = 0;i < COUNT; i++) {
                os.write(msg.getBytes("UTF-8"));
                expected.append(msg);
            }
            os.flush();
            os.close();
            
            int count = 0;
            while (StringUtils.isBlank(readOnServer.get()) && count < 4) {
                readOnServer.wait(2000);
                count++;
            }
        }
        assertEquals(expected.toString(), readOnServer.get());
        
        // TODO: TEST CERTS BEING ADDED *AFTER* THE FACTORIES ARE SET UP!!
    }

    private void startServer(final LanternSocketsUtil util) throws Exception {
        
        UDTReceiver.connectionExpiryDisabled = true;
        final InetAddress myHost = InetAddress.getByName("127.0.0.1");
        //final UDTServerSocket server = new UDTServerSocket(myHost, SERVER_PORT);
        final ServerSocket server = new NetServerSocketUDT();
        server.bind(new InetSocketAddress(myHost, SERVER_PORT));
        //server.bind(SERVER_PORT, 100, myHost);
        //final ServerSocket server = new ServerSocket(SERVER_PORT, 100, myHost);
        
        final Runnable runner = new Runnable() {

            @Override
            public void run() {
                try {
                    accept(server, util);
                } catch (final Exception e) {
                    // TODO Auto-generated catch block
                    e.printStackTrace();
                }
            }
        };
        final Thread t = new Thread(runner, "UDT-SSL-Test-Thread");
        t.setDaemon(true);
        t.start();
    }

    protected void accept(final ServerSocket server, 
        final LanternSocketsUtil util) throws Exception {
        final Socket socket = server.accept();
        final SSLSocketFactory sslSocketFactory = util.newTlsSocketFactoryJavaCipherSuites();
        //final ServerSocket server = factory.createServerSocket();
        //server.bind(new InetSocketAddress(SERVER_PORT));
        
        //final SSLSocketFactory sslSocketFactory =
        //    (SSLSocketFactory)SSLSocketFactory.getDefault();
        final SSLSocket sslSocket =
            (SSLSocket)sslSocketFactory.createSocket(socket,
                socket.getInetAddress().getHostAddress(),
                //"127.0.0.1",
                socket.getPort(), false);
        sslSocket.setUseClientMode(false);
        sslSocket.startHandshake();
        
        final InputStream is = sslSocket.getInputStream();
        final int length = msg.getBytes("UTF-8").length * COUNT;
        final byte[] data = new byte[length];
        for (int i = 0; i < length; i++) {
            final int cur = is.read();
            data[i] = (byte) cur;
        }
        final OutputStream os = sslSocket.getOutputStream();
        for (int i = 0; i < COUNT; i++) {
            os.write(msg.getBytes("UTF-8"));
        }
        os.flush();
        
        is.close();
        
        
        final String read = new String(data, "UTF-8");
        synchronized (readOnServer) {
            readOnServer.set(read.trim());
            readOnServer.notifyAll();
        }
    }
}
