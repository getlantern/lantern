package org.mg.server;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smackx.filetransfer.FileTransferListener;
import org.jivesoftware.smackx.filetransfer.FileTransferManager;
import org.jivesoftware.smackx.filetransfer.FileTransferRequest;
import org.jivesoftware.smackx.filetransfer.IncomingFileTransfer;
import org.littleshoot.proxy.Launcher;

public class DefaultXmppProxy implements XmppProxy {

    /**
     * Buffer size between input and output
     */
    private static final int BUFFER_SIZE = 8192;
    
    private final ExecutorService requestReceiverPool = 
        Executors.newCachedThreadPool();
    
    private final ExecutorService requestProcessorPool = 
        Executors.newCachedThreadPool();
    
    public DefaultXmppProxy() {
        // Start the HTTP proxy server that we relay data to. It has more
        // developed logic for handling different types of requests, and we'd
        // otherwise have to duplicate that here.
        Launcher.main("7777");
    }
    
    public void start() throws XMPPException, IOException {
        final ConnectionConfiguration config = 
            new ConnectionConfiguration("talk.google.com", 5222, "gmail.com");
        config.setCompressionEnabled(true);
        final XMPPConnection conn = new XMPPConnection(config);
        conn.connect();
        final Properties props = new Properties();
        final File propsFile = 
            new File(System.getProperty("user.home"), "mg.properties");
        if (!propsFile.isFile()) {
            System.err.println("No properties file found at "+propsFile+
                ". That file is required and must contain a property for " +
                "'user' and 'pass'.");
            System.exit(0);
        }
        props.load(new FileInputStream(propsFile));
        final String user = props.getProperty("user");
        final String pass = props.getProperty("pass");
        conn.login(user, pass);
        
        System.out.println("USER: "+conn.getUser());
        
        final FileTransferManager ftm = new FileTransferManager(conn);
        // Create the listener
        ftm.addFileTransferListener(new FileTransferListener() {
            public void fileTransferRequest(final FileTransferRequest request) {
                System.out.println("GOT FILE TRANSFER REQUEST!!");
                requestReceiverPool.submit(new Runnable() {
                    public void run() {
                        try {
                            final IncomingFileTransfer ift = request.accept();
                            final File tempFile =  
                                File.createTempFile(String.valueOf(request.hashCode()), null);
                            ift.recieveFile(tempFile);
                            
                            //readRequest(request);
                            while (!ift.isDone()) {
                                //System.out.println(ift.getStatus());
                                try {
                                    Thread.sleep(200);
                                } catch (InterruptedException e) {
                                    // TODO Auto-generated catch block
                                    e.printStackTrace();
                                }
                            }
                            HttpRequestRelayer relayer = new HttpRequestRelayer(conn, request, tempFile);
                            relayer.run();
                            
                        } catch (XMPPException e) {
                            // TODO Auto-generated catch block
                            e.printStackTrace();
                        } catch (IOException e) {
                            // TODO Auto-generated catch block
                            e.printStackTrace();
                        }
                        System.out.println("FILE NAME: "+request.getFileName());
                        System.out.println("DESCRIPTION: "+request.getDescription());
                    }
                });
            }
        });
    }

    /*
    private void readRequest(final FileTransferRequest request) 
        throws XMPPException, IOException {
        final IncomingFileTransfer itf = request.accept();
        final long fileSize = request.getFileSize();
        final InputStream in = itf.recieveFile();
        final byte[] b = new byte[BUFFER_SIZE];
        int count = 0;
        int amountWritten = 0;

        // We actually write to a file here because it could be a large POST
        // request.
        final File tempFile = 
            File.createTempFile(String.valueOf(request.hashCode()), null);
        final OutputStream out = new FileOutputStream(tempFile);
        do {
            // write to the output stream
            try {
                out.write(b, 0, count);
            } catch (IOException e) {
                throw new XMPPException("error writing to output stream", e);
            }

            amountWritten += count;

            // read more bytes from the input stream
            try {
                count = in.read(b);
            } catch (IOException e) {
                throw new XMPPException("error reading from input stream", e);
            }
        } while (count != -1 && !itf.getStatus().equals(Status.cancelled));

        // the connection was likely terminated abrubtly if these are not equal
        if (!itf.getStatus().equals(Status.cancelled) && 
             itf.getError() == Error.none && amountWritten != fileSize) {
            itf.setStatus(Status.error);
            itf.setError(Error.connection);
        }
        System.out.println("Read: "+IOUtils.toString(new FileInputStream(tempFile)));
    }
    */
}
