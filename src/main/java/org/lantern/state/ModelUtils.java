package org.lantern.state;

import org.lantern.GeoData;
import org.littleshoot.commom.xmpp.GoogleOAuth2Credentials;

/**
 * Interface for utility methods depending on the state model.
 */
public interface ModelUtils {

    boolean shouldProxy();

    GeoData getGeoData(String hostAddress);

    void loadClientSecrets();

    boolean isConfigured();

    boolean isOauthConfigured();

    GoogleOAuth2Credentials newGoogleOauthCreds(String resource);

    boolean isInClosedBeta(String email);

    void addToClosedBeta(String to);

    void loadOAuth2ClientSecretsFile(String optionValue);

    void loadOAuth2UserCredentialsFile(String optionValue);

    void syncConnectingStatus(String msg);

}
