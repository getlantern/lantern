package org.mg.server;

import java.io.IOException;

import org.jivesoftware.smack.XMPPException;

/**
 * Class for launching the MG server.
 */
public class Launcher {

    public static void main(final String... args) {
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
