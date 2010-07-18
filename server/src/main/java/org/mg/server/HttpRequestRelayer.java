package org.mg.server;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.Socket;
import java.util.Scanner;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.apache.commons.io.IOUtils;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smackx.filetransfer.FileTransferManager;
import org.jivesoftware.smackx.filetransfer.FileTransferRequest;
import org.jivesoftware.smackx.filetransfer.OutgoingFileTransfer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class HttpRequestRelayer implements Runnable {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File tempFile;
    private final FileTransferRequest request;
    
    private static final ExecutorService writeRelayPool = 
        Executors.newCachedThreadPool();
    
    private static final ExecutorService readRelayPool = 
        Executors.newCachedThreadPool();
    
    private final HttpClient httpclient = new DefaultHttpClient();

    private final XMPPConnection conn;
    
    /**
     * The default small buffer size to use.  This is smaller because HTTP
     * requests aren't typically that big.
     */
    private static final int SMALL_BUFFER_SIZE = 1024 * 4;
    
    /**
     * The default buffer size to use. This is the same size Jetty uses -- 
     * bigger because we're typically serving files.
     */
    private static final int LARGE_BUFFER_SIZE = 1024 * 16;

    public HttpRequestRelayer(final XMPPConnection conn, 
        final FileTransferRequest request, final File tempFile) {
        this.conn = conn;
        this.request = request;
        this.tempFile = tempFile;
    }

    public void run() {
        try {
            relay();
        } catch (final IOException e) {
            e.printStackTrace();
        }
        /*
        final Scanner scan;
        try {
            scan = new Scanner(this.tempFile);
        } catch (final FileNotFoundException e) {
            log.error("Could not locate temp file??", e);
            return;
        }
        scan.useDelimiter("\r\n");
        
        final String requestLine = scan.next();
        final Scanner requestScan = new Scanner(requestLine);
        final String method = requestScan.next();
        if (method.equalsIgnoreCase("GET")) {
            final String path = requestScan.next();
            final HttpGet httpget = new HttpGet("http://www.google.com/");
        }
        */
    }
    
    private void relay() throws IOException {
        final Socket relay = new Socket("127.0.0.1", 7777);
        System.out.println("CONNECTED: " + relay.isConnected());
        
        //final OutputStream externalOs = sock.getOutputStream();
        //final InputStream externalIs = sock.getInputStream();
        final InputStream externalIs = new FileInputStream(this.tempFile);
        final OutputStream os = relay.getOutputStream();
        final InputStream is = relay.getInputStream();
    
        System.out.println("RELAYING:\n"+IOUtils.toString(new FileInputStream(this.tempFile)));
        
        // Thread the reads and the writes. "Reads" and "writes" of course
        // depend on what connection you're taking the perspective of, but
        // it doesn't really matter.
        threadedCopy(externalIs, os, "Read", relay, readRelayPool);
        final Runnable writeRelay = new Runnable() {
            
            public void run() {
                final FileTransferManager ftm = new FileTransferManager(conn);
                final OutgoingFileTransfer oft = 
                    ftm.createOutgoingFileTransfer(request.getRequestor());
                oft.sendStream(is, "Relay-File", 20, "Relaying-From-Remote-Host");

            }
        };
        writeRelayPool.submit(writeRelay);
    }

    private void threadedCopy(final InputStream is, 
        final OutputStream os, final String threadNameId, 
        final Socket sock, ExecutorService pool) {
        final Runnable runner = new Runnable() {
            public void run() {
                try {
                    copyLarge(is, os, SMALL_BUFFER_SIZE);
                }
                catch (final IOException e) {
                    // This will happen if the other side just closes the 
                    // socket, for example.
                    log.debug("Error copying socket data on "+threadNameId, e);
                }
                catch (final Throwable t) {
                    log.warn("Error copying socket data on "+threadNameId, t);
                }
                finally {
                    // We always close the stream and socket because the copy
                    // method above will only either throw an exception or
                    // will have reached the end of the stream -- the closing
                    // of the external socket.  We need to always make sure
                    // the relay socket closes as well.
                    
                    //IOUtils.closeQuietly(os);
                }
            }
        };
        pool.submit(runner);
    }
    
    private long copyLarge(final InputStream input, 
        final OutputStream output, final int bufferSize) throws IOException {
        final byte[] buffer = new byte[bufferSize];
        long count = 0;
        int n = 0;
        while (-1 != (n = input.read(buffer))) 
            {
            output.write(buffer, 0, n);
            count += n;
            }
        log.debug("Copied bytes: {}", count);
        System.out.println("Copied bytes: "+count);
        return count;
    }
}
