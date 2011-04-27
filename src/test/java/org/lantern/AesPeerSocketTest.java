package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.fail;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.Test;


public class AesPeerSocketTest {

    private static final String MSG = createMessage();
    
    private final AtomicReference<String> serverMessage = 
        new AtomicReference<String>();
    
    @Test public void testAes() throws Exception {
        final String msg = createMessage();
        
        // Get the KeyGenerator
        final byte[] key = LanternUtils.generateKey();
        final byte[] encodedMessage = LanternUtils.encode(key, msg);
        
        startServer(encodedMessage.length, key);
        final Socket client = new Socket("127.0.0.1", 8889);
        final OutputStream os = client.getOutputStream();
        os.write(encodedMessage);
        os.flush();
        os.close();
        
        int waits = 0;
        while (serverMessage.get() == null && waits < 20) {
            Thread.sleep(400);
            waits++;
        }
        final String server = serverMessage.get();
        if (server.equalsIgnoreCase("error")) {
            fail("Got an error!!");
        }
        else {
            assertEquals(MSG, server);
        }
    }

    private static String createMessage() {
        final String hello = "Hello World \n";
        final StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 100; i++) {
            sb.append(hello);
        }
        return sb.toString();
    }

    private void startServer(
        final int length, final byte[] rawKey) throws IOException {
        final ServerSocket server = new ServerSocket();
        server.bind(new InetSocketAddress("127.0.0.1", 8889));
        final Runnable runner = new Runnable() {
            public void run() {
                try {
                    final Socket sock = server.accept();
                    final InputStream is = sock.getInputStream();
                    final byte[] ciphertext = new byte[length];
                    is.read(ciphertext);
                    
                    final byte[] original = 
                        LanternUtils.decode(rawKey, ciphertext);
                    final String originalString = new String(original);
                    
                    assertEquals("Did not get original string", MSG, 
                        originalString);
                    serverMessage.set(originalString);
                    server.close();
              
                } catch (final Exception e) {
                    //e.printStackTrace();
                    serverMessage.set("ERROR");
                }
            }
        };
        final Thread t = new Thread(runner);
        t.setDaemon(true);
        t.start();
    }
    
    public static String asHex (byte buf[]) {
        StringBuffer strbuf = new StringBuffer(buf.length * 2);
        int i;

        for (i = 0; i < buf.length; i++) {
         if ((buf[i] & 0xff) < 0x10)
          strbuf.append("0");

         strbuf.append(Long.toString(buf[i] & 0xff, 16));
        }

        return strbuf.toString();
       }
}
