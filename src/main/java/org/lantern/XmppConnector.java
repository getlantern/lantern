package org.lantern;

import java.io.IOException;

import javax.security.auth.login.CredentialException;

import org.jivesoftware.smack.XMPPConnection;
import org.lantern.event.Events;
import org.lantern.event.PublicIpAndTokenEvent;
import org.lantern.state.InternalState;
import org.lantern.state.Modal;
import org.lantern.state.Model;
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

    private final Model model;

    private final InternalState internalState;

    @Inject
    public XmppConnector(final XmppHandler xmppHandler,
            final Model model, final InternalState internalState) {
        this.xmppHandler = xmppHandler;
        this.model = model;
        this.internalState = internalState;
        Events.register(this);
    }
    
    @Subscribe
    public void onConnectedWithRefresh(final PublicIpAndTokenEvent proxyAndToken) {
        log.debug("Got connected with refresh event");
        connect();
    }

    private void connect() {
        log.debug("Connecting to XMPP");

        if (!model.isSetupComplete()) {
            log.debug("Still setting up...");
            // Handle states associated with the Google login screen
            // during the setup sequence.
            model.getConnectivity().setGtalkAuthorized(true);
            internalState.setNotInvited(false);
            internalState.setModalCompleted(Modal.authorize);
            internalState.advanceModal(null);
        }
        // Every once in awhile we've seen the client get stuck in the
        // connecting state when restarted, and we want to make sure to
        // advance from it when we're auto-connecting again on startup.
        else if (model.getModal() == Modal.connecting) {
            internalState.setNotInvited(false);
            internalState.advanceModal(null);
        }
        
        final XmppP2PClient<FiveTuple> client = this.xmppHandler.getP2PClient();
        if (client != null) {
            final XMPPConnection conn = client.getXmppConnection();
            if (conn != null && conn.isConnected()) {
                log.debug("Not reconnecting");
                return;
            }
        }

        // Wait for a second to connect with XMPP, as other things
        // like the S3ConfigFetcher in practice are simultaneously
        // hitting the server and potentially creating a new user
        // if this is a first run. Note this relies on the caller calling
        // from an asynchronous event class.
        try {
            Thread.sleep(3000);
        } catch (final InterruptedException e1) {
        }
        try {
            xmppHandler.connect();
        } catch (final CredentialException e) {
            log.error("Could not log in with OAUTH?", e);
            //Events.syncModal(model, Modal.authorize);
        } catch (final IOException e) {
            log.info("We can't connect (internet connection died?). " +
                "The XMPP layer should automatically retry.", e);
        }
    }
}
