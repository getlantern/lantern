package org.mg.server;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;

import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smackx.filetransfer.FileTransferListener;
import org.jivesoftware.smackx.filetransfer.FileTransferManager;
import org.jivesoftware.smackx.filetransfer.FileTransferRequest;
import org.jivesoftware.smackx.filetransfer.IncomingFileTransfer;

public class DefaultXmppProxy implements XmppProxy {

    private final ExecutorService pool = Executors.newCachedThreadPool();
    
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
                pool.submit(new Runnable() {
                    public void run() {
                        final IncomingFileTransfer itf = request.accept();
                        System.out.println("FILE NAME: "+request.getFileName());
                        System.out.println("DESCRIPTION: "+request.getDescription());
                    }
                });
            }
        });
    }

}
