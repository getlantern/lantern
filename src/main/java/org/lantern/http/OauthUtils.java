package org.lantern.http;

import java.io.IOException;
import java.io.InputStream;
import java.util.Collection;
import java.util.HashSet;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.http.Header;
import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.StatusLine;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpDelete;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.client.methods.HttpRequestBase;
import org.apache.http.entity.StringEntity;
import org.apache.http.util.EntityUtils;
import org.lantern.TokenResponseEvent;
import org.lantern.event.Events;
import org.lantern.state.Model;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.api.client.auth.oauth2.ClientParametersAuthentication;
import com.google.api.client.auth.oauth2.Credential;
import com.google.api.client.auth.oauth2.CredentialRefreshListener;
import com.google.api.client.auth.oauth2.RefreshTokenRequest;
import com.google.api.client.auth.oauth2.TokenErrorResponse;
import com.google.api.client.auth.oauth2.TokenResponse;
import com.google.api.client.auth.oauth2.TokenResponseException;
import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets;
import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets.Details;
import com.google.api.client.googleapis.auth.oauth2.GoogleCredential;
import com.google.api.client.http.GenericUrl;
import com.google.api.client.http.HttpRequestFactory;
import com.google.api.client.http.HttpResponse;
import com.google.api.client.http.apache.ApacheHttpTransport;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.jackson.JacksonFactory;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Utility methods for OAUTH.
 */
@Singleton
public class OauthUtils {

    private static final Logger LOG = LoggerFactory.getLogger(OauthUtils.class);

    public static final String REDIRECT_URL =
        "http://localhost:7777/oauth2callback";
    
    private static long nextExpiryTime = System.currentTimeMillis();
    private final Model model;
    
    private static TokenResponse lastResponse;

    private final HttpClientFactory httpClientFactory;

    private static GoogleClientSecrets secrets = null;
    
    @Inject
    public OauthUtils(final HttpClientFactory httpClientFactory, 
            final Model model) {
        this.httpClientFactory = httpClientFactory;
        this.model = model;
    }

    /**
     * Obtains the oauth tokens. Note the refresh token should already be
     * set when this is called. This will attempt to obtain the tokens directly
     * and will then use a proxy if necessary.
     * 
     * @return The tokens.
     * @throws IOException If we cannot access the tokens either directory or
     * through a fallback proxy.
     */
    public TokenResponse oauthTokens() throws IOException {
        LOG.debug("Refreshing ACCESS token");
        
        // Get the tokens with a direct request followed by a proxied request
        // if the direct request fails.
        final HttpFallbackFunc<TokenResponse> func = 
                new HttpFallbackFunc<TokenResponse>() {

            @Override
            public TokenResponse call(final HttpClient client, 
                    final String refreshToken) throws IOException {
                return oauthTokens(client, refreshToken);
            }
        };
        return func.execute();
    }
    
    /**
     * This class allows implementors to make HTTP calls that automatically 
     * first try to connect directly and then fallback to available proxies if
     * direct connections don't work.
     *
     * @param <T> The return type of the underlying function that should be
     * first tried directly and then with a fallback proxy.
     */
    private abstract class HttpFallbackFunc<T> {
        
        public abstract T call(final HttpClient client, final String refreshToken) 
                throws IOException;
        
        /**
         * Execute the desired call with a fallback. If the fallback is used,
         * the implemented call method will get invoked a second time. The
         * fallback will be used if the direct attempt throws an exception.
         * 
         * @return The implementor's return type.
         * @throws IOException If there's an error running the function with
         * both direct attempts and fallback proxy attempts.
         */
        public T execute() throws IOException {
            LOG.debug("Making oauth call with fallback...");
            
            final String refreshToken = model.getSettings().getRefreshToken();
            if (StringUtils.isBlank(refreshToken)) {
                LOG.error("No refresh token!");
                throw new NullPointerException("No refresh token!");
            }
            
            final HttpClient directClient =  httpClientFactory.newDirectClient();
            final Collection<HttpHost> usedHosts = new HashSet<HttpHost>();
            
            try {
                return call(directClient, refreshToken);
            } catch (final IOException e) {
                LOG.debug("Could not execute call directly", e);
            }
            
            // We implement a bit of our own retry handling here to make sure
            // we get through.
            final int maxAttempts = 4;
            int attempts = 0;
            while (attempts < maxAttempts) {
                final HttpHost proxy = httpClientFactory.newProxy();
                if (usedHosts.contains(proxy)) {
                    break;
                }
                usedHosts.add(proxy);
                final HttpClient proxiedClient = 
                    httpClientFactory.newClient(proxy, true);
                try {
                    //return oauthTokens(proxiedClient, refreshToken);
                    return call(proxiedClient, refreshToken);
                } catch (final IOException e) {
                    LOG.debug("Could not execute call even with fallback at {}", 
                            proxy.getHostName(), e);
                }
                attempts++;
                
                // Avoid hammering the server...
                try {
                    Thread.sleep(1000);
                } catch (InterruptedException e) {
                }
            }
            final String msg = "Could not successfully make call even with fallback!";
            LOG.error(msg);
            throw new IOException(msg);
        }
    }
    
    public static TokenResponse oauthTokens(final HttpClient httpClient, 
            final String refreshToken) 
            throws IOException {
        LOG.debug("Obtaining access token...");
        if (lastResponse != null) {
            LOG.debug("We have a cached response...");
            final long now = System.currentTimeMillis();
            if (now < nextExpiryTime) {
                LOG.debug("Returning cached token");
                return lastResponse;
            } else {
                LOG.debug(now +" greater than " + nextExpiryTime);
            }
        }
        final ApacheHttpTransport httpTransport = 
                new ApacheHttpTransport(httpClient);
        final GoogleClientSecrets creds = OauthUtils.loadClientSecrets();
        final Details installed = creds.getInstalled();
        try {
            final TokenResponse response =
                new RefreshTokenRequest(httpTransport, 
                    new JacksonFactory(), new GenericUrl(
                        "https://accounts.google.com/o/oauth2/token"), refreshToken)
                    .setClientAuthentication(new ClientParametersAuthentication(
                            installed.getClientId(), 
                            installed.getClientSecret()))
                        .execute();
            
            final long expiry = response.getExpiresInSeconds();
            LOG.info("Got expiry time: {}", expiry);
            nextExpiryTime = System.currentTimeMillis() + 
                ((expiry-10) * 1000);
            LOG.debug("Next expiry: "+nextExpiryTime);
            
            LOG.info("Got response: {}", response);
            lastResponse = response;
            return lastResponse;
        } catch (final TokenResponseException e) {
            LOG.error("Token error -- maybe revoked or unauthorized?", e);
            throw new IOException("Problem with token -- maybe revoked?", e);
        } catch (final IOException e) {
            LOG.warn("IO exception while trying to refresh token.", e);
            throw e;
        }
    }

    public String postRequest(final String endpoint, final String json) 
            throws IOException {
        
        final HttpPost post = new HttpPost(endpoint);
        post.setHeader("Content-Type", "application/json");
        final HttpEntity requestEntity = new StringEntity(json, "UTF-8");
        post.setEntity(requestEntity);
        return httpRequest(post);
    }
    
    public String getRequest(final String endpoint) throws IOException {
        return httpRequest(new HttpGet(endpoint));
    }
    
    public String deleteRequest(final String endpoint) throws IOException {
        return httpRequest(new HttpDelete(endpoint));
    }

    private String httpRequest(final HttpRequestBase request) throws IOException {
        final HttpFallbackFunc<String> func = new HttpFallbackFunc<String>() {

            @Override
            public String call(final HttpClient client, final String refreshToken)
                    throws IOException {
                return httpRequest(client, request);
            }
        };
        return func.execute();
    }
    
    private String httpRequest(final HttpClient httpClient,
            final HttpRequestBase request) throws IOException {
        configureOauth(httpClient, request);
       
        try {
            final org.apache.http.HttpResponse response = httpClient.execute(request);
            final StatusLine line = response.getStatusLine();
            final Header cl = response.getFirstHeader("Content-Length");
            if (cl != null && cl.getValue().equals("0")) {
                return "";
            }
            final int code = line.getStatusCode();
            
            // Check for 204 No Content -- i.e. no entity body.
            if (code == 204) {
                return "";
            }
            final HttpEntity entity = response.getEntity();
            final String body = IOUtils.toString(entity.getContent());
            EntityUtils.consume(entity);
            
            if (code < 200 || code > 299) {
                throw new IOException("Bad response code: "+code+"\n"+body);
            }
            return body;
        } catch (final IOException e) {
            throw e;
        } finally {
            request.reset();
        }
    }
 
    private void configureOauth(final HttpClient httpClient, 
            final HttpRequestBase request) throws IOException {
        final String accessToken = accessToken(httpClient);
        request.setHeader("Authorization", "Bearer "+accessToken);
        request.setHeader("Accept-Charset", "UTF-8");
        request.setHeader("Accept", "application/json");
    }

    public String accessToken(final HttpClient httpClient) throws IOException {
        final String refresh = this.model.getSettings().getRefreshToken();
        if (StringUtils.isBlank(refresh)) {
            LOG.error("Can't call Oauth APIs without refresh token! " +
                "Should be set earlier");
            throw new Error("No refresh token set");
        }
        return OauthUtils.oauthTokens(httpClient, refresh).getAccessToken();
    } 
    
    public static synchronized GoogleClientSecrets loadClientSecrets() throws IOException {
        if (secrets != null) {
            return secrets;
        }
        InputStream is = null;
        try {
            is = OauthUtils.class.getResourceAsStream(
                "/client_secrets_installed.json");
            secrets = GoogleClientSecrets.load(new JacksonFactory(), is);
            //LOG.debug("Secrets: {}", secrets);
            return secrets;
        } finally {
            IOUtils.closeQuietly(is);
        }
    }
    

    /**
     * Utility class for making an Oauth request to a Google service.
     *
     * NOTE: Currently unused but an interesting technique for future 
     * reference.
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
