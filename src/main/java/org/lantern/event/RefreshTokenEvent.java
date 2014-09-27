package org.lantern.event;

import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class RefreshTokenEvent {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final String refreshToken;

    public RefreshTokenEvent(final String refreshToken) {
        if (StringUtils.isBlank(refreshToken)) {
            log.error("Blank token!");
            throw new IllegalArgumentException("Blank token!");
        }
        this.refreshToken = refreshToken;
    }

    public String getRefreshToken() {
        return refreshToken;
    }

}
