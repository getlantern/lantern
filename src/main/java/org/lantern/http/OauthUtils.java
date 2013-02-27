package org.lantern.http;

import java.io.IOException;
import java.io.InputStream;

import org.apache.commons.io.IOUtils;
import org.lantern.TokenResponseEvent;
import org.lantern.event.Events;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.api.client.auth.oauth2.ClientParametersAuthentication;
import com.google.api.client.auth.oauth2.Credential;
import com.google.api.client.auth.oauth2.CredentialRefreshListener;
import com.google.api.client.auth.oauth2.TokenErrorResponse;
import com.google.api.client.auth.oauth2.TokenResponse;
import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets;
import com.google.api.client.googleapis.auth.oauth2.GoogleCredential;
import com.google.api.client.http.GenericUrl;
import com.google.api.client.http.HttpRequestFactory;
import com.google.api.client.http.HttpResponse;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.jackson.JacksonFactory;

public class OauthUtils {

    private static final Logger LOG = LoggerFactory.getLogger(OauthUtils.class);
    
    public static final String REDIRECT_URL =
        "http://localhost:7777/oauth2callback";
    
    private static GoogleClientSecrets secrets = null;
    
    public static GoogleClientSecrets loadClientSecrets() throws IOException {
        if (secrets != null) {
            return secrets;
        }
        InputStream is = null;
        try {
            is = OauthUtils.class.getResourceAsStream(
                "/client_secrets_installed.json");
            secrets = GoogleClientSecrets.load(new JacksonFactory(), is);
            //log.debug("Secrets: {}", secrets);
            return secrets;
        } finally {
            IOUtils.closeQuietly(is);
        }
    }

    /**
     * Utility class for making an Oauth request to a Google service.
     *
     * @param access The access token.
     * @param refresh The refresh token.
     * @param encodedUrl The URL to visit.
     *
     * @return The {@link HttpResponse}.
     * @throws IOException If there's an error loading the client secrets or
     * accessing the service.
     */
    public static HttpResponse googleOauth(final String access,
        final String refresh, final String encodedUrl) throws IOException{

        final GoogleClientSecrets creds = OauthUtils.loadClientSecrets();
        final CredentialRefreshListener refreshListener =
            new CredentialRefreshListener() {

                @Override
                public void onTokenResponse(final Credential credential,
                    final TokenResponse tokenResponse) throws IOException {
                    LOG.info("Got token response...sending event");
                    Events.eventBus().post(new TokenResponseEvent(tokenResponse));
                }

                @Override
                public void onTokenErrorResponse(final Credential credential,
                    final TokenErrorResponse tokenErrorResponse)
                    throws IOException {
                    LOG.warn("Error response:\n"+
                            tokenErrorResponse.toPrettyString());
                }
            };
        final GoogleCredential gc = new GoogleCredential.Builder().
            setTransport(new NetHttpTransport()).
            setJsonFactory(new JacksonFactory()).
            addRefreshListener(refreshListener).
            setClientAuthentication(new ClientParametersAuthentication(
                creds.getInstalled().getClientId(),
                creds.getInstalled().getClientSecret())).build();

        gc.setAccessToken(access);
        gc.setRefreshToken(refresh);

        final GenericUrl url = new GenericUrl(encodedUrl);
        final HttpRequestFactory requestFactory =
            gc.getTransport().createRequestFactory(gc);
        return requestFactory.buildGetRequest(url).execute();

    }
}
