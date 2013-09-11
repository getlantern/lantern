package org.lantern.state;

import org.lantern.oauth.LanternGoogleOAuth2Credentials;

/**
 * Interface for utility methods depending on the state model.
 */
public interface ModelUtils {

    boolean shouldProxy();

    void loadClientSecrets();

    boolean isConfigured();

    boolean isOauthConfigured();

    LanternGoogleOAuth2Credentials newGoogleOauthCreds(String resource);

    boolean isInClosedBeta(String email);

    void addToClosedBeta(String to);

    void loadOAuth2ClientSecretsFile(String optionValue);

    void loadOAuth2UserCredentialsFile(String optionValue);

    void syncConnectingStatus(String msg);

    boolean isGet();

    public ClientFriend makeFriend(String email);
}
