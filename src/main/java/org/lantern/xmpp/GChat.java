package org.lantern.xmpp;

import java.util.Collection;

import org.jivesoftware.smack.XMPPException;

public interface GChat {

    /**
     * Connects and logs in to GChat.
     * 
     * @param userName The user's Google user name.
     * @param password The user's password.
     * @param ip The public IP address to report to GChat contacts.
     * @throws XMPPException If there's an error connecting to the XMPP server.
     */
    void connect(String userName, String password, String ip) 
        throws XMPPException;
    
    Collection<String> getAllIps();
}
