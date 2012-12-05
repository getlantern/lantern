package org.lantern;

import org.lantern.event.GoogleTalkStateEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Links Google login state with connectivity state in give mode. This is 
 * because in give mode the only connectivity we can have is connectivity to
 * Google Talk, whereas in get mode connections to proxies are more relevant.
 */
public class GiveModeConnectivityHandler {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    public GiveModeConnectivityHandler() {
        //Events.register(this);
    }
    
    //@Subscribe
    public void onGoogleTalkState(final GoogleTalkStateEvent event) {
        /*
        if (model.getSettings().isGetMode()) {
            log.info("Not linking Google Talk state to connectivity " +
                "state in get mode");
            return;
        }
        final GoogleTalkState state = event.getState();
        final ConnectivityStatus cs;
        switch (state) {
            case connected:
                cs = ConnectivityStatus.CONNECTED;
                break;
            case notConnected:
                cs = ConnectivityStatus.DISCONNECTED;
                break;
            case LOGIN_FAILED:
                cs = ConnectivityStatus.DISCONNECTED;
                break;
            case connecting:
                cs = ConnectivityStatus.CONNECTING;
                break;
            case LOGGING_OUT:
                cs = ConnectivityStatus.DISCONNECTED;
                break;
            default:
                log.error("Should never get here...");
                cs = ConnectivityStatus.DISCONNECTED;
                break;
        }
        log.info("Linking Google Talk state {} to connectivity state {}", 
            state, cs);
        Events.eventBus().post(
            new ConnectivityStatusChangeEvent(cs));
            */
    }
}