package org.lantern;

import java.io.IOException;

import javax.security.auth.login.CredentialException;

import org.jivesoftware.smack.XMPPConnection;
import org.lantern.event.Events;
import org.lantern.event.PublicIpAndTokenEvent;
import org.lantern.state.InternalState;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.util.FiveTuple;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class for automatically connecting to the XMPP server on startup. We can
 * only connect when we've successfully added a proxy and have a valid 
 * OAuth token, however, and this waits for both of those to be true.
 */
@Singleton
public class XmppConnector {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final XmppHandler xmppHandler;

    @Inject
    public XmppConnector(final XmppHandler xmppHandler,
            final InternalState internalState) {
        this.xmppHandler = xmppHandler;
        Events.register(this);
    }
    
    @Subscribe
    public void onConnectedWithRefresh(final PublicIpAndTokenEvent proxyAndToken) {
        log.debug("Got connected with refresh event");
        connect();
    }

    private void connect() {
        log.debug("Connecting to XMPP");

        final XmppP2PClient<FiveTuple> client = this.xmppHandler.getP2PClient();
        if (client != null) {
            final XMPPConnection conn = client.getXmppConnection();
            if (conn != null && conn.isConnected()) {
                log.debug("Not reconnecting");
                return;
            }
        }

        try {
            xmppHandler.connect();
        } catch (final CredentialException e) {
            log.error("Could not log in with OAUTH?", e);
        } catch (final IOException e) {
            log.info("We can't connect (internet connection died?). " +
                "The XMPP layer should automatically retry.", e);
        }
    }
}
