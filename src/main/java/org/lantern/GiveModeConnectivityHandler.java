package org.lantern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

/**
 * Links Google login state with connectivity state in give mode.
 */
public class GiveModeConnectivityHandler {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    public GiveModeConnectivityHandler() {
        LanternHub.register(this);
    }
    
    @Subscribe
    public void onGoogleTalkState(final GoogleTalkStateEvent event) {
        if (LanternHub.settings().isGetMode()) {
            log.info("Not linking Google Talk state to connectivity " +
                "state in get mode");
            return;
        }
        final GoogleTalkState state = event.getState();
        final ConnectivityStatus cs;
        switch (state) {
            case LOGGED_IN:
                cs = ConnectivityStatus.CONNECTED;
                break;
            case LOGGED_OUT:
                cs = ConnectivityStatus.DISCONNECTED;
                break;
            case LOGIN_FAILED:
                cs = ConnectivityStatus.DISCONNECTED;
                break;
            case LOGGING_IN:
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
        LanternHub.eventBus().post(
            new ConnectivityStatusChangeEvent(cs));
    }
}