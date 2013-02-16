package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.concurrent.atomic.AtomicReference;

import javax.net.ssl.SSLHandshakeException;
import javax.net.ssl.SSLServerSocket;
import javax.net.ssl.SSLServerSocketFactory;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

import org.apache.commons.lang3.StringUtils;
import org.junit.Test;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.util.ThreadUtils;

public class LanternSocketsUtilTest {

    private static final int SERVER_PORT = LanternUtils.randomPort();

    private final String msg = "test\n";
    
    @Test
    public void testMutualAuthentication() throws Exception {
        //System.setProperty("javax.net.debug", "all");
        //System.setProperty("javax.net.debug", "ssl");
        //final LanternKeyStoreManager ksm = TestUtils.getKsm();
        //final LanternTrustStore trustStore = TestUtils.getTrustStore();
        
        final KeyStoreManager ksm = new LanternKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(null, ksm);
        //final LanternTrustStore trustStore = TestUtils.buildTrustStore();
        final String testId = "test@gmail.com/somejidresource";
        trustStore.addBase64Cert(testId, ksm.getBase64Cert(testId));
        
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
