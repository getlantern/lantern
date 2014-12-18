package org.lantern.state;

import org.lantern.oauth.LanternGoogleOAuth2Credentials;

/**
 * Interface for utility methods depending on the state model.
 */
public interface ModelUtils {

    boolean shouldProxy();

    void loadClientSecrets();

    boolean isConfigured();

    LanternGoogleOAuth2Credentials newGoogleOauthCreds(String resource);

    boolean isInClosedBeta(String email);

    void addToClosedBeta(String to);

    void syncConnectingStatus(String msg);

}
