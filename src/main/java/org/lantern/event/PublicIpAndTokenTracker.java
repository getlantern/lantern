package org.lantern.event;

import org.apache.commons.lang3.StringUtils;
import org.lantern.ConnectivityChangedEvent;
import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * This class centralizes tracking of the combination of a valid refresh token
 * and a valid proxy. Several services rely on that combination, including the
 * XMPP server login and connecting to the friends API.
 */
@Singleton
public class PublicIpAndTokenTracker {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private volatile boolean hasPublicIp = false;
    private volatile String refresh;

    @Inject
    public PublicIpAndTokenTracker(final Model model) {
        log.debug("Creating tracker");
        Events.register(this);
        this.refresh = model.getSettings().getRefreshToken();
    }
    
    @Subscribe
    synchronized public void onPublicIp(final PublicIpEvent pce) {
        log.debug("Got public IP");
        this.hasPublicIp = true;
        if (StringUtils.isNotBlank(refresh)) {
            log.debug("Have both public IP and refresh token, posting event");
            Events.asyncEventBus()
                    .post(new PublicIpAndTokenEvent(this.refresh));
        }
    }

    @Subscribe
    synchronized public void onConnectivityChanged(ConnectivityChangedEvent cce) {
        if (!cce.isConnected()) {
            log.debug("Lost connectivity, resetting public IP to false");
            this.hasPublicIp = false;
        }
    }

    @Subscribe
    synchronized public void onRefreshToken(final RefreshTokenEvent refreshEvent) {
        log.debug("Got refresh token");
        this.refresh = refreshEvent.getRefreshToken();
        if (this.hasPublicIp) {
            log.debug("Have both refresh token and public IP, posting event");
            Events.asyncEventBus()
                    .post(new PublicIpAndTokenEvent(this.refresh));
        }
    }    
}
