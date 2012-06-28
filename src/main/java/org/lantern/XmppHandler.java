package org.lantern;

import java.io.IOException;

import javax.security.auth.login.CredentialException;

import org.jivesoftware.smack.packet.Presence;
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

    /**
     * Adds or removes a peer depending on the peer's availability 
     * advertised in its presence.
     * 
     * @param p The presence.
     * @param from The full peer JID.
     */
    void addOrRemovePeer(Presence p, String from);

    /**
     * Sends an invite to the specified email address.
     * 
     * @param email The email address to send the invite to.
     */
    void sendInvite(String email);

}
