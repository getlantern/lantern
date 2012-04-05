package org.lantern;

import java.io.IOException;

import javax.security.auth.login.CredentialException;

import org.littleshoot.commom.xmpp.XmppP2PClient;

/**
 * Interface for dealing with any XMPP interaction in Lantern.
 */
public interface XmppHandler extends ProxyStatusListener, ProxyProvider {

    void disconnect();

    /**
     * Connects using stored credentials.
     * 
     * @throws IOException If we cannot connect to the server.
     * @throws CredentialException If the credentials are incorrect.
     */
    void connect() throws IOException, CredentialException;

    XmppP2PClient getP2PClient();

    boolean isLoggedIn();

    /**
     * Connects using stored credentials.
     * 
     * @param email The user's e-mail address.
     * @param pwd The user's password.
     * @throws IOException If we cannot connect to the server.
     * @throws CredentialException If the credentials are incorrect.
     */
    void connect(String email, String pwd) throws IOException, 
        CredentialException;

    void clearProxies();

}
