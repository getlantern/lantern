package org.lantern.event;

import org.apache.commons.lang3.StringUtils;
import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * This class centralizes tracking of the combination of a valid refresh 
 * token and a valid proxy. Several services rely on that combination,
 * including the XMPP server login and connecting to the friends API.
 */
@Singleton
public class PublicIpAndTokenTracker {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private boolean hasRefresh = false;

    private boolean hasPublicIp = false;

    private String refresh;
    
    @Inject
    public PublicIpAndTokenTracker(final Model model) {
        log.debug("Creating tracker");
        Events.register(this);
        this.refresh = model.getSettings().getRefreshToken();
        if (StringUtils.isNotBlank(refresh)) {
            this.hasRefresh = true;
        }
    }
    
    /**
     * Resets the state of the tracker (useful when reinitializing system).
     */
    public void reset() {
        this.hasPublicIp = false;
    }
    
    @Subscribe
    public void onRefreshToken(final RefreshTokenEvent refreshEvent) {
        log.debug("Got refresh token -- loading friends");
        this.refresh = refreshEvent.getRefreshToken();
        synchronized (this) {
            this.hasRefresh = true;
            if (this.hasPublicIp) {
                // We use a synchronous event bus here so the creator of the
                // refresh event can decide whether this is ultimately called
                // asynchronously or not.
                Events.eventBus().post(new PublicIpAndTokenEvent(this.refresh));
            }
        }
    }
    
    @Subscribe
    public void onPublicIp(final PublicIpEvent pce) {
        synchronized (this) {
            this.hasPublicIp = true;
            if (this.hasRefresh) {
                log.debug("Posting event!!");
                // We use a synchronous event bus here so the creator of the
                // proxy event can decide whether this is ultimately called
                // asynchronously or not.
                Events.eventBus().post(new PublicIpAndTokenEvent(this.refresh));
            }
        }
    }
}
