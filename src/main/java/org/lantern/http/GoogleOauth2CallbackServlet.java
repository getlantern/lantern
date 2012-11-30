package org.lantern.http;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

import javax.security.auth.login.CredentialException;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.NameValuePair;
import org.apache.http.client.entity.UrlEncodedFormEntity;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.message.BasicNameValuePair;
import org.apache.http.util.EntityUtils;
import org.codehaus.jackson.map.ObjectMapper;
import org.lantern.LanternConstants;
import org.lantern.LanternHub;
import org.lantern.NotInClosedBetaException;
import org.lantern.RuntimeSettings;
import org.lantern.XmppHandler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets;
import com.google.api.client.json.jackson.JacksonFactory;

public class GoogleOauth2CallbackServlet extends HttpServlet {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private static final long serialVersionUID = -957838028594747197L;

    private final GoogleOauth2CallbackServer googleOauth2CallbackServer;

    private final XmppHandler xmppHandler;
    
    public GoogleOauth2CallbackServlet(
        final GoogleOauth2CallbackServer googleOauth2CallbackServer,
        final XmppHandler xmppHandler) {
        this.googleOauth2CallbackServer = googleOauth2CallbackServer;
        this.xmppHandler = xmppHandler;
    }
    
    @Override
    protected void doGet(final HttpServletRequest req, 
        final HttpServletResponse resp) throws ServletException, 
        IOException {
        processRequest(req, resp);
    }
    @Override
    protected void doPost(final HttpServletRequest req, 
        final HttpServletResponse resp) throws ServletException, 
        IOException {
        processRequest(req, resp);
    }
    
    private void processRequest(final HttpServletRequest req, 
        final HttpServletResponse resp) {
        final String uri = req.getRequestURI();
        log.debug("Received URI: {}", uri);
        final Map<String, String> params = HttpUtils.toParamMap(req);
        log.debug("Params: {}", params);
        
        // Redirect back to the dashboard right away to continue giving the
        // user feedback. The UI will fetch the current state doc.
        log.info("Redirecting from oauth back to dashboard...");
        final String dashboard = RuntimeSettings.getLocalEndpoint();
        try {
            resp.sendRedirect(dashboard);
            resp.flushBuffer();
        } catch (final IOException e) {
            log.info("Error redirecting to the dashboard?", e);
        }

        // Kill our temporary oauth callback server.
        this.googleOauth2CallbackServer.stop();
        
        fetchOauthAndLoginToGoogleTalk(params.get("code"));
    }

    private void fetchOauthAndLoginToGoogleTalk(final String code) {
        // Now we need to do an HTTP post to obtain the refresh token and
        // the access token.
        final String redirectUrl = "http://localhost:7777/oauth2callback";
        final DefaultHttpClient client = new DefaultHttpClient();
        InputStream is = null;
        HttpPost post = null;
        try {
            is = new FileInputStream("client_secrets_installed.json");
            final GoogleClientSecrets secrets =
                GoogleClientSecrets.load(new JacksonFactory(), is);
            log.debug("Secrets: {}", secrets);
            
            final Map<String, String> installed = 
                (Map<String, String>) secrets.get("installed");
            post = new HttpPost("https://accounts.google.com/o/oauth2/token");
            
            final String clientId = installed.get("client_id");
            final String clientSecret = installed.get("client_secret");
            final List<? extends NameValuePair> nvps = Arrays.asList(
                new BasicNameValuePair("code", code),
                new BasicNameValuePair("client_id", clientId),
                new BasicNameValuePair("client_secret", clientSecret),
                new BasicNameValuePair("redirect_uri", redirectUrl),
                new BasicNameValuePair("grant_type", "authorization_code")
                );
            final HttpEntity entity = 
                new UrlEncodedFormEntity(nvps, LanternConstants.UTF8);
            post.setEntity(entity);
            
            log.debug("About to execute post!");
            final HttpResponse response = client.execute(post);

            log.debug("Got response status: {}", response.getStatusLine());
            final HttpEntity responseEntity = response.getEntity();
            // do something useful with the response body
            // and ensure it is fully consumed
            final String body = IOUtils.toString(responseEntity.getContent());
            EntityUtils.consume(responseEntity);
            
            final ObjectMapper om = new ObjectMapper();
            final Map<String, String> oauthToks = 
                om.readValue(body, Map.class);
            log.debug("Got oath data: {}", oauthToks);
            
            final String accessToken = oauthToks.get("access_token");
            final String refreshToken = oauthToks.get("refresh_token");
            
            if (StringUtils.isNotBlank(accessToken) &&
                StringUtils.isNotBlank(refreshToken)) {
                try {
                    // Note the e-mail is actually ignored when we login to 
                    // Google Talk.
                    LanternHub.settings().setEmail("anon@getlantern.org");
                    LanternHub.settings().setClientID(clientId);
                    LanternHub.settings().setClientSecret(clientSecret);
                    LanternHub.settings().setAccessToken(accessToken);
                    LanternHub.settings().setRefreshToken(refreshToken);
                    LanternHub.settings().setUseGoogleOAuth2(true);
                    this.xmppHandler.connect();
                } catch (final CredentialException e) {
                    // Not sure what to do here. This *should* never happen.
                    log.error("Could not log in with OAUTH?", e);
                } catch (final NotInClosedBetaException e) {
                    // TODO: Set the modal state corresponding with not in closed
                    // beta?
                } catch (final IOException e) {
                    // TODO Auto-generated catch block
                    e.printStackTrace();
                }
            } else {
                // Treat this the same as a credential exception? I.e. what
                // happens if the user cancels?
            }
        } catch (final IOException e) {
            IOUtils.closeQuietly(is);
            throw new Error("Could not load oauth URL?", e);
        } finally {
            if (post != null) {
                post.releaseConnection();
            }
        }
    }
}
