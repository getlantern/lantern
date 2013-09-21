package org.lantern.oauth;

import java.util.concurrent.atomic.AtomicReference;

import org.apache.commons.lang3.StringUtils;
import org.lantern.event.Events;
import org.lantern.event.RefreshTokenEvent;
import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class RefreshToken {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Model model;
    private final AtomicReference<String> tok = new AtomicReference<String>();
    
    @Inject
    public RefreshToken(final Model model) {
        this.model = model;
        Events.register(this);
    }
    
    
    public String refreshToken() {
        if (StringUtils.isNotBlank(this.tok.get())) {
            log.debug("Returning existing token...");
            return this.tok.get();
        }
        final String existing = this.model.getSettings().getRefreshToken();
        if (StringUtils.isNotBlank(existing)) {
            this.tok.set(existing);
            return existing;
        }
        synchronized (this) {
            if (StringUtils.isBlank(this.tok.get())) {
                log.debug("Waiting for token...");
                try {
                    wait();
                } catch (InterruptedException e) {
                }
            }
            return this.tok.get();
        }
    }
    
    public void onRefreshToken(final RefreshTokenEvent rte) {
        log.debug("Received token!");
        synchronized (this) {
            final String token = rte.getRefreshToken();
            if (StringUtils.isBlank(token)) {
                log.warn("Blank token?");
                return;
            }
            this.tok.set(token);
            notifyAll();
        }
    }

}
