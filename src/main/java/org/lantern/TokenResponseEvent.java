package org.lantern;

import com.google.api.client.auth.oauth2.TokenResponse;

public class TokenResponseEvent {

    private final TokenResponse tokenResponse;

    public TokenResponseEvent(final TokenResponse tokenResponse) {
        this.tokenResponse = tokenResponse;
    }

    public TokenResponse getTokenResponse() {
        return tokenResponse;
    }

}
