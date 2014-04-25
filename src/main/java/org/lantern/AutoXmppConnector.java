package org.lantern;

import java.io.IOException;

import javax.security.auth.login.CredentialException;

import org.lantern.event.Events;
import org.lantern.event.ProxyAndTokenEvent;
import org.lantern.state.InternalState;
import org.lantern.state.Modal;
import org.lantern.state.Model;
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
public class AutoXmppConnector {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final XmppHandler xmppHandler;

    private final Model model;

    private final InternalState internalState;

    @Inject
    public AutoXmppConnector(final XmppHandler xmppHandler,
            final Model model, final InternalState internalState) {
        this.xmppHandler = xmppHandler;
        this.model = model;
        this.internalState = internalState;
        Events.register(this);
    }
    
    @Subscribe
    public void onConnectedWithRefresh(final ProxyAndTokenEvent proxyAndToken) {
        log.debug("Got connected with refresh event");
        connect();
    }

    private void connect() {
        try {
            this.xmppHandler.connect();
            if (model.getModal() == Modal.connecting) {
                internalState.advanceModal(null);
            }
        } catch (final IOException e) {
            log.debug("Could not login", e);
        } catch (final CredentialException e) {
            log.debug("Bad credentials", e);
            Events.syncModal(model, Modal.authorize);
        } catch (final NotInClosedBetaException e) {
            log.warn("Not in closed beta!!", e);
            internalState.setNotInvited(true);
        }
    }
    

}
