package org.lantern.event;

public class RefreshTokenEvent {

    private final String refreshToken;

    public RefreshTokenEvent(final String refreshToken) {
        this.refreshToken = refreshToken;
    }

    public String getRefreshToken() {
        return refreshToken;
    }

}
