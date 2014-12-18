package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.util.concurrent.atomic.AtomicReference;

import javax.net.ssl.SSLHandshakeException;
import javax.net.ssl.SSLServerSocket;
import javax.net.ssl.SSLServerSocketFactory;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

import org.apache.commons.lang3.StringUtils;
import org.junit.Test;
import org.junit.experimental.categories.Category;
import org.lantern.TestCategories.TrustStoreTests;
import org.littleshoot.util.ThreadUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Category(TrustStoreTests.class)
public class LanternSocketsUtilTest {

    private static Logger LOG = 
            LoggerFactory.getLogger(LanternSocketsUtilTest.class);
    
    private static final int SERVER_PORT = LanternUtils.randomPort();

    private final String msg = "testMessage";
    
    @Test
    public void testTrustStoreConnectionAndMutualAuthentication() throws Exception {
        //System.setProperty("javax.net.debug", "all");
        //System.setProperty("javax.net.debug", "ssl");
        LOG.debug("Testing Lantern mutually authenticated sockets");
        final LanternKeyStoreManager ksm = new LanternKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        final String testId = "test@gmail.com/somejidresource";
        trustStore.addCert(new URI(testId), LanternUtils.certFromBase64(ksm.getBase64Cert(testId)));
        
        final LanternSocketsUtil util = new LanternSocketsUtil(trustStore);
        
        final AtomicReference<String> data = new AtomicReference<String>();
        accept(util, data);
        
        Thread.yield();
        Thread.yield();
        
        try {
            testClient(util.newTlsSocketFactoryJavaCipherSuites(), data);
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
