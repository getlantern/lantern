package org.mg.server;

import java.io.IOException;
import java.lang.Thread.UncaughtExceptionHandler;

import org.jivesoftware.smack.XMPPException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class for launching the MG server.
 */
public class Launcher {

    private static final Logger log = LoggerFactory.getLogger(Launcher.class);
    
    public static void main(final String... args) {
        Thread.setDefaultUncaughtExceptionHandler(new UncaughtExceptionHandler() {
            public void uncaughtException(final Thread t, final Throwable e) {
                log.error("Uncaught exception", e);
            }
        });
        
        final XmppProxy proxy = new DefaultXmppProxy();
        try {
            proxy.start();
        } catch (XMPPException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
        // Keep the server open.
        synchronized (proxy) {
            try {
                proxy.wait();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }
}
