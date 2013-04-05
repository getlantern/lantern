package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketAddress;
import java.net.URI;
import java.util.Arrays;
import java.util.concurrent.atomic.AtomicReference;

import javax.net.ServerSocketFactory;
import javax.net.SocketFactory;
import javax.net.ssl.SSLHandshakeException;
import javax.net.ssl.SSLServerSocket;
import javax.net.ssl.SSLServerSocketFactory;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

import org.apache.commons.lang3.StringUtils;
import org.junit.Test;
import org.junit.experimental.categories.Category;
import org.lantern.TestCategories.TrustStoreTests;
import org.lantern.state.Mode;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.util.ThreadUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Category(TrustStoreTests.class)
public class LanternSocketsUtilTest {

    private static Logger LOG = 
            LoggerFactory.getLogger(LanternSocketsUtilTest.class);
    
    private static final int SERVER_PORT = LanternUtils.randomPort();

    private final String msg = "testMessage";
    
    private final AtomicReference<String> readOnServer =
        new AtomicReference<String>("");
    

    @Test
    public void testSSL() throws Exception {
        TestUtils.load(true);
        final LanternKeyStoreManager ksm = TestUtils.getKsm();
        TestUtils.getModel().getSettings().setMode(Mode.get);
        System.setProperty("javax.net.debug", "ssl");
        LOG.debug(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing SSL...");
        Launcher.configureCipherSuites();
        final XmppHandler xmpp = TestUtils.getXmppHandler();
        // We have to actually connect because the ID we use in the keystore
        // is our XMPP JID.
        xmpp.connect();

        // Since we're connecting to ourselves for testing, we need to add our
        // own key to the *trust store* from the key store.
        
        final LanternTrustStore ts = TestUtils.getTrustStore();
        ts.addBase64Cert(new URI(xmpp.getJid()), ksm.getBase64Cert(xmpp.getJid()));


        final SocketFactory clientFactory =
            TestUtils.getSocketsUtil().newTlsSocketFactory();
        final ServerSocketFactory serverFactory =
            TestUtils.getSocketsUtil().newTlsServerSocketFactory();

        final SocketAddress endpoint =
            new InetSocketAddress("127.0.0.1", LanternUtils.randomPort());

        final SSLServerSocket ss =
            (SSLServerSocket) serverFactory.createServerSocket();
        
        LOG.debug("SUPPORTED: "+Arrays.asList(ss.getSupportedCipherSuites()));
        ss.bind(endpoint);

        acceptIncoming(ss);
        Thread.sleep(400);

        final SSLSocket client = (SSLSocket) clientFactory.createSocket();
        client.setSoTimeout(30000);
        client.connect(endpoint, 2000);

        LOG.debug(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing SSL...");
        assertTrue(client.isConnected());

        LOG.debug(System.getProperty("javax.net.ssl.trustStore")+" "+LanternTrustStore.PASS+" Testing SSL...");
        synchronized (readOnServer) {
            final OutputStream os = client.getOutputStream();
            os.write(msg.getBytes("UTF-8"));
            os.close();
            readOnServer.wait(2000);
        }

        assertEquals(msg, readOnServer.get());
    }

    private void acceptIncoming(final SSLServerSocket ss) {
        final Runnable runner = new Runnable() {

            @Override
            public void run() {
                try {

                    final SSLSocket sock = (SSLSocket) ss.accept();

                    LOG.debug("Incoming cipher list..." +
                        Arrays.asList(sock.getEnabledCipherSuites()));
                    final InputStream is = sock.getInputStream();
                    final int length = msg.getBytes("UTF-8").length;
                    final byte[] data = new byte[length];
                    int bytes = 0;
                    while (bytes < length) {
                        bytes += is.read(data, bytes, length - bytes);
                    }
                    final String read = new String(data, "UTF-8");
                    synchronized (readOnServer) {
                        readOnServer.set(read.trim());
                        readOnServer.notifyAll();
                    }
                } catch (final IOException e) {
                    e.printStackTrace();
                }
            }
        };
        final Thread t = new Thread(runner, "test-thread");
        t.setDaemon(true);
        t.start();
    }
    
    @Test
    public void testMutualAuthentication() throws Exception {
        //System.setProperty("javax.net.debug", "all");
        //System.setProperty("javax.net.debug", "ssl");
        //final LanternKeyStoreManager ksm = TestUtils.getKsm();
        //final LanternTrustStore trustStore = TestUtils.getTrustStore();
        
        final KeyStoreManager ksm = new LanternKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        //final LanternTrustStore trustStore = TestUtils.buildTrustStore();
        final String testId = "test@gmail.com/somejidresource";
        trustStore.addBase64Cert(new URI(testId), ksm.getBase64Cert(testId));
        
        final LanternSocketsUtil util = new LanternSocketsUtil(null, trustStore);
        //final LanternSocketsUtil util = TestUtils.getSocketsUtil();
        
        final AtomicReference<String> data = new AtomicReference<String>();
        accept(util, data);
        
        Thread.yield();
        Thread.yield();
        
        try {
            testClient(util.newTlsSocketFactory(), data);
        } catch (Exception e) {
            fail("Should have connected no problem!!\n"+ThreadUtils.dumpStack(e));
        }
        
        // Now test with a client without our credentials from the keystore 
        // and make sure it fails.
        try {
            testClient((SSLSocketFactory) SSLSocketFactory.getDefault(), data);
            fail("Should have failed!!\n"+ThreadUtils.dumpStack());
        } catch (Exception e) {
            // Note there are other types of SSLHandshakeException other than
            // client authentication errors (what we're after in this case),
            // but checking specifically for that would involve reading the
            // exception message, which likely varies across JVMs and platforms.
            assertTrue(e instanceof SSLHandshakeException);
        }
        //TestUtils.close();
    }

    private void testClient(final SSLSocketFactory client, 
        final AtomicReference<String> data) throws Exception {
        data.set("");
        final Socket sock = client.createSocket();
        sock.setSoTimeout(1000);
        sock.connect(new InetSocketAddress("127.0.0.1", SERVER_PORT), 2000);
        
        final OutputStream os = sock.getOutputStream();
        os.write(msg.getBytes());
        os.flush();
        
        synchronized (data) {
            if (StringUtils.isBlank(data.get())) {
                data.wait(1000);
            }
        }
        
        assertEquals("Did not get data on server?", msg, data.get());
    }

    private void accept(final LanternSocketsUtil util, 
        final AtomicReference<String> data) throws Exception {
        final SSLServerSocketFactory factory = util.newTlsServerSocketFactory();
        final SSLServerSocket server = (SSLServerSocket) factory.createServerSocket();
        
        server.bind(new InetSocketAddress("127.0.0.1", SERVER_PORT));
        final Runnable runner = new Runnable() {
            
            @Override
            public void run() {
                try {
                    while (true) {
                        final SSLSocket sock = (SSLSocket) server.accept();
                        sock.setSoTimeout(1000);
                        final InputStream is = sock.getInputStream();
                        final byte[] readData = new byte[msg.length()];
                        for (int i = 0; i < msg.length(); i++) {
                            final int r = is.read();
                            readData[i] = (byte)r;
                        }
                        final String readString = new String(readData);
                        synchronized (data) {
                            data.set(readString);
                            data.notifyAll();
                        }
                    }
                } catch (final SSLHandshakeException e) {
                    e.printStackTrace();
                } catch (final IOException e) {
                }
            }
        };
        final Thread t = new Thread(runner, "Test-SSL-Server-Thread");
        t.setDaemon(true);
        t.start();
    }

}
