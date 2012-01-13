package org.lantern;

import java.io.IOException;

import org.lastbamboo.common.p2p.P2PClient;

/**
 * Interface for dealing with any XMPP interaction in Lantern.
 */
public interface XmppHandler extends ProxyStatusListener, ProxyProvider {

    void disconnect();

    void connect() throws IOException;

    P2PClient getP2PClient();

}
