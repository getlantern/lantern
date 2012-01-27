package org.lantern;

import java.io.IOException;

import org.littleshoot.commom.xmpp.XmppP2PClient;

/**
 * Interface for dealing with any XMPP interaction in Lantern.
 */
public interface XmppHandler extends ProxyStatusListener, ProxyProvider {

    void disconnect();

    void connect() throws IOException;

    XmppP2PClient getP2PClient();

    boolean isLoggedIn();

    void connect(String email, String pwd) throws IOException;

}
