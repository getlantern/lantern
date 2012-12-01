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
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.message.BasicNameValuePair;
import org.apache.http.util.EntityUtils;
import org.codehaus.jackson.map.ObjectMapper;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.lantern.Events;
import org.lantern.LanternConstants;
import org.lantern.LanternHub;
import org.lantern.NotInClosedBetaException;
import org.lantern.RuntimeSettings;
import org.lantern.XmppHandler;
import org.lantern.event.SyncEvent;
import org.lantern.state.Modal;
import org.lantern.state.Model;
import org.lantern.state.SyncPath;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets;
import com.google.api.client.json.jackson.JacksonFactory;

/**
 * Servlet for handling OAuth callbacks from Google. The associated code is
 * converted into OAuth tokens that are used to login to Google Talk and to
 * obtain any other necessary data.
 */
public class GoogleOauth2CallbackServlet extends HttpServlet {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private static final long serialVersionUID = -957838028594747197L;

    private final GoogleOauth2CallbackServer googleOauth2CallbackServer;

    private final XmppHandler xmppHandler;

    private final Model model;
    
    public GoogleOauth2CallbackServlet(
        final GoogleOauth2CallbackServer googleOauth2CallbackServer,
        final XmppHandler xmppHandler, final Model model) {
        this.googleOauth2CallbackServer = googleOauth2CallbackServer;
        this.xmppHandler = xmppHandler;
        this.model = model;
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

        final String code = params.get("code");
        if (StringUtils.isBlank(code)) {
            log.info("Did not get authorization code in params: {}", params);
            final String error = params.get("error");
            log.info("Got error: {}", error);
            log.info("Setting modal on model: {}", model);
            this.model.setModal(Modal.authorize);
            redirectToDashboard(resp);
            return;
        } 

        // Theoretically this should actually be oauth connecting here, but 
        // this should do. Make sure we set this before sending the user
        // back to the dashboard. We don't need to post an event because the
        // dashboard is about to get fully reloaded.
        this.model.setModal(Modal.gtalkConnecting);
        redirectToDashboard(resp);
        
        // Kill our temporary oauth callback server.
        this.googleOauth2CallbackServer.stop();
        
        final DefaultHttpClient client = new DefaultHttpClient();
        final Map<String, String> allToks;
        try {
            allToks = loadAllToks(client, code);
        } catch (final IOException e) {
            log.error("Could not load client secrets!!", e);
            redirectToDashboard(resp);
            return;
        }

        connectToGoogleTalk(allToks);
        fetchEmail(allToks, client);
    }

    private void fetchEmail(final Map<String, String> allToks, 
        final DefaultHttpClient client) {
        final String endpoint = 
            "https://www.googleapis.com/oauth2/v1/userinfo";
        final String accessToken = allToks.get("access_token");
        final HttpGet get = new HttpGet(endpoint);
        get.setHeader(HttpHeaders.Names.AUTHORIZATION, "Bearer "+accessToken);
        
        try {
            log.debug("About to execute get!");
            final HttpResponse response = client.execute(get);

            log.debug("Got response status: {}", response.getStatusLine());
            final HttpEntity entity = response.getEntity();
            final String body = IOUtils.toString(entity.getContent());
            EntityUtils.consume(entity);
            log.info("GOT RESPONSE BODY FOR EMAIL:\n"+body);
            final ObjectMapper om = new ObjectMapper();
            final Map<String, String> emailMap = 
                om.readValue(body, Map.class);
            final String email = emailMap.get("email");
            this.model.getSettings().setUserId(email);
        } catch (final IOException e) {
            log.warn("Could not connect to Google?", e);
        } finally {
            get.releaseConnection();
        }
        
    }

    private void connectToGoogleTalk(final Map<String, String> allToks) {
        final String accessToken = allToks.get("access_token");
        final String refreshToken = allToks.get("refresh_token");
        
        if (StringUtils.isBlank(accessToken) ||
            StringUtils.isBlank(refreshToken)) {
            log.warn("Not access or refresh token -- not logging in!!");
            return;
        } else {
            // Treat this the same as a credential exception? I.e. what
            // happens if the user cancels?
        }
        
        final String clientId = allToks.get("client_id");
        final String clientSecret = allToks.get("client_secret");
        
        // Note the e-mail is actually ignored when we login to 
        // Google Talk.
        LanternHub.settings().setEmail("anon@getlantern.org");
        LanternHub.settings().setClientID(clientId);
        LanternHub.settings().setClientSecret(clientSecret);
        LanternHub.settings().setAccessToken(accessToken);
        LanternHub.settings().setRefreshToken(refreshToken);
        LanternHub.settings().setUseGoogleOAuth2(true);
        
        // We kick this off on another thread, as otherwise it would be 
        // a Jetty thread, and we're about to kill the server. When the
        // server is killed, the connecting thread would otherwise be 
        // interrupted.
        final Thread t = new Thread(new Runnable() {

            @Override
            public void run() {
                try {
                    xmppHandler.connect();
                } catch (final CredentialException e) {
                    // Not sure what to do here. This *should* never happen.
                    log.error("Could not log in with OAUTH?", e);
                } catch (final NotInClosedBetaException e) {
                    model.setModal(Modal.notInvited);
                    Events.asyncEventBus().post(new SyncEvent(SyncPath.MODAL, Modal.notInvited));
                } catch (final IOException e) {
                    // TODO Auto-generated catch block
                    e.printStackTrace();
                }
            }
            
        }, "Google-Talk-Connect-From-Oauth-Servlet-Thread");
        t.setDaemon(true);
        t.start();
    }
    

    private Map<String, String> loadAllToks(final DefaultHttpClient client,
        final String code) throws IOException {
        final Map<String, String> secrets = loadClientSecrets();
        final String redirectUrl = "http://localhost:7777/oauth2callback";
        final HttpPost post = 
            new HttpPost("https://accounts.google.com/o/oauth2/token");
        try {
            final String clientId = secrets.get("client_id");
            final String clientSecret = secrets.get("client_secret");
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
            final String body = IOUtils.toString(responseEntity.getContent());
            EntityUtils.consume(responseEntity);
            
            final ObjectMapper om = new ObjectMapper();
            final Map<String, String> oauthToks = 
                om.readValue(body, Map.class);
            log.debug("Got oath data: {}", oauthToks);
            oauthToks.put("client_id", clientId);
            oauthToks.put("client_secret", clientSecret);
            return oauthToks;
        } finally {
            post.releaseConnection();
        }
    }

    private Map<String, String> loadClientSecrets() throws IOException {
        InputStream is = null;
        try {
            is = new FileInputStream("client_secrets_installed.json");
            final GoogleClientSecrets secrets =
                GoogleClientSecrets.load(new JacksonFactory(), is);
            log.debug("Secrets: {}", secrets);
            
            return (Map<String, String>) secrets.get("installed");
        } finally {
            IOUtils.closeQuietly(is);
        }
    }

    private void redirectToDashboard(final HttpServletResponse resp) {
        final String dashboard = RuntimeSettings.getLocalEndpoint();
        try {
            resp.sendRedirect(dashboard);
            resp.flushBuffer();
        } catch (final IOException e) {
            log.info("Error redirecting to the dashboard?", e);
        }
    }
}
