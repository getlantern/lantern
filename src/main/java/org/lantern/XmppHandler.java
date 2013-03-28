package org.lantern;

import java.io.IOException;

import javax.security.auth.login.CredentialException;

import org.jivesoftware.smack.packet.Packet;
import org.jivesoftware.smack.packet.Presence;
import org.lantern.state.Settings.Mode;
import org.lastbamboo.common.ice.MappedServerSocket;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.util.FiveTuple;

/**
 * Interface for dealing with any XMPP interaction in Lantern.
 */
public interface XmppHandler extends LanternService {

    void disconnect();

    /**
     * Connects using stored credentials.
     *
     * @throws IOException If we cannot connect to the server.
     * @throws CredentialException If the credentials are incorrect.
     * @throws NotInClosedBetaException Exception for when the user is not
     * in the closed beta.
     */
    void connect() throws IOException, CredentialException, NotInClosedBetaException;

    XmppP2PClient<FiveTuple> getP2PClient();

    boolean isLoggedIn();

    /**
     * Connects using stored credentials.
     *
     * @param email The user's e-mail address.
     * @param pwd The user's password.
     * @throws IOException If we cannot connect to the server.
     * @throws CredentialException If the credentials are incorrect.
     * @throws NotInClosedBetaException Exception for when the user is not
     * in the closed beta.
     */
    void connect(String email, String pwd) throws IOException,
        CredentialException, NotInClosedBetaException;

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
     * @return
     */
    boolean sendInvite(String email);

    /**
     * Stop subscribing to the presence of another user.
     *
     * @param jid The JID of the user to stop subscribing to.
     */
    void unsubscribe(String jid);

    /**
     * Reject the subscription request of the specified user.
     *
     * @param jid The JID of the subscription request to reject.
     */
    void unsubscribed(String jid);

    void addToRoster(String jid);

    void removeFromRoster(String jid);

    void subscribe(String jid);

    void subscribed(String jid);

    @Override
    void start();

    @Override
    void stop();

    String getJid();

    MappedServerSocket getMappedServer();

    void sendPacket(Packet packet);

    void sendMode(Mode mode);
}
