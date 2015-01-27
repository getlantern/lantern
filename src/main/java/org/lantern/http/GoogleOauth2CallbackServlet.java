package org.lantern.http;

import io.netty.handler.codec.http.HttpHeaders;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.NameValuePair;
import org.apache.http.StatusLine;
import org.apache.http.client.HttpClient;
import org.apache.http.client.entity.UrlEncodedFormEntity;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.message.BasicNameValuePair;
import org.apache.http.util.EntityUtils;
import org.codehaus.jackson.JsonParseException;
import org.codehaus.jackson.map.JsonMappingException;
import org.lantern.JsonUtils;
import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
import org.lantern.MessageKey;
import org.lantern.Proxifier.ProxyConfigurationError;
import org.lantern.ProxyService;
import org.lantern.Tr;
import org.lantern.event.Events;
import org.lantern.oauth.OauthUtils;
import org.lantern.proxy.GetModeProxy;
import org.lantern.state.InternalState;
import org.lantern.state.Modal;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;
import org.lantern.state.ModelUtils;
import org.lantern.state.Profile;
import org.lantern.state.Settings;
import org.lantern.state.StaticSettings;
import org.lantern.state.SyncPath;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Charsets;

/**
 * Servlet for handling OAuth callbacks from Google. The associated code is
 * converted into OAuth tokens that are used to login to Google Talk and to
 * obtain any other necessary data.
 */
public class GoogleOauth2CallbackServlet extends HttpServlet {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private static final long serialVersionUID = -957838028594747197L;

    private final GoogleOauth2CallbackServer googleOauth2CallbackServer;

    private final Model model;

    private final ModelIo modelIo;

    private final ProxyService proxifier;

    private final HttpClientFactory httpClientFactory;

    private final ModelUtils modelUtils;

    private final InternalState internalState;

    private final GetModeProxy proxy;

    public GoogleOauth2CallbackServlet(
        final GoogleOauth2CallbackServer googleOauth2CallbackServer,
        final Model model, final ModelIo modelIo,
        final ProxyService proxifier, final HttpClientFactory httpClientFactory,
        final ModelUtils modelUtils,
        final InternalState internalState,
        final GetModeProxy proxy) {
        this.googleOauth2CallbackServer = googleOauth2CallbackServer;
        this.model = model;
        this.modelIo = modelIo;
        this.proxifier = proxifier;
        this.httpClientFactory = httpClientFactory;
        this.modelUtils = modelUtils;
        this.internalState = internalState;
        this.proxy = proxy;
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

        // Before redirecting to Google, we set up the proxy to proxy
        // access to accounts.google.com for the oauth exchange. That's just
        // temporary, though, and we now cancel it.
        this.proxy.unrequireHighQOS();
        try {
            this.proxifier.stopProxying();
        } catch (final ProxyConfigurationError e) {
            log.warn("Could not stop proxy?", e);
        }

        // Redirect back to the dashboard right away to continue giving the
        // user feedback. The UI will fetch the current state doc.
        log.debug("Redirecting from oauth back to dashboard...");
        final String code = params.get("code");
        if (StringUtils.isBlank(code)) {
            // This will happen when the user cancels oauth.
            log.debug("Did not get authorization code in params: {}", params);
            final String error = params.get("error");
            log.error("Got error: {}", error);
            log.debug("Setting modal on model: {}", model);
            this.model.setModal(Modal.authorize);
            redirectToDashboard(resp);
            return;
        }

        // Theoretically this should actually be oauth connecting here, but
        // this should do. Make sure we set this before sending the user
        // back to the dashboard. We don't need to post an event because the
        // dashboard is about to get fully reloaded.
        modelUtils.syncConnectingStatus(Tr.tr(MessageKey.TALK_SERVERS));
        log.debug("Setting modal to connecting...");
        advanceModal();
        redirectToDashboard(resp);

        int port = this.googleOauth2CallbackServer.getPort();
        // Kill our temporary oauth callback server.
        this.googleOauth2CallbackServer.stop();

        final HttpClient client = this.httpClientFactory.newClient();

        final Map<String, Object> allToks;
        try {
            allToks = loadAllToks(code, port, client);
        } catch (final IOException e) {
            log.error("Could not load all oauth tokens!!", e);
            redirectToDashboard(resp);
            return;
        }

        configureOauthTokens(allToks);
        fetchEmail(allToks, client);
    }

    private void advanceModal() {
        log.debug("Still setting up...");
        // Handle states associated with the Google login screen
        // during the setup sequence.
        model.getConnectivity().setGtalkAuthorized(true);
        internalState.setModalCompleted(Modal.authorize);
        internalState.advanceModal(null);
    }

    /**
     * Fetches user's e-mail - only public for testing.
     *
     * @param allToks OAuth tokens.
     * @param httpClient The HTTP client.
     */
    public int fetchEmail(final Map<String, Object> allToks,
            final HttpClient httpClient) {
        final String endpoint =
            "https://www.googleapis.com/oauth2/v1/userinfo";
        final Object accessToken = allToks.get("access_token");
        final HttpGet get = new HttpGet(endpoint);
        get.setHeader(HttpHeaders.Names.AUTHORIZATION, "Bearer "+accessToken);

        try {
            log.debug("About to execute get!");
            final HttpResponse response = httpClient.execute(get);
            final StatusLine line = response.getStatusLine();
            log.debug("Got response status: {}", line);
            final HttpEntity entity = response.getEntity();
            final String body = IOUtils.toString(entity.getContent(), "UTF-8");
            EntityUtils.consume(entity);
            log.debug("GOT RESPONSE BODY FOR EMAIL:\n"+body);

            final int code = line.getStatusCode();
            if (code < 200 || code > 299) {
                log.error("OAuth error?\n"+line);
                return code;
            }

            final Profile profile = JsonUtils.OBJECT_MAPPER.readValue(body, Profile.class);
            this.model.setProfile(profile);
            Events.sync(SyncPath.PROFILE, profile);
            //final String email = profile.getEmail();
            //this.model.getSettings().setEmail(email);
            return code;
        } catch (final IOException e) {
            log.warn("Could not connect to Google?", e);
        } finally {
            get.reset();
        }
        return -1;
    }

    private void configureOauthTokens(final Map<String, Object> allToks) {
        final String accessToken = (String) allToks.get("access_token");
        final String refreshToken = (String) allToks.get("refresh_token");
        final Integer expiry = (Integer) allToks.get("expires_in");
        final Settings set = this.model.getSettings();
        LanternUtils.setOauth(set, refreshToken, accessToken, expiry, modelIo);
    }

    private Map<String, Object> loadAllToks(final String code, int port,
        final HttpClient httpClient) throws IOException {
        log.debug("Loading oauth tokens from https://accounts.google.com/o/oauth2/token");
        final HttpPost post =
            new HttpPost("https://accounts.google.com/o/oauth2/token");
        final List<? extends NameValuePair> nvps = Arrays.asList(
            new BasicNameValuePair("code", code),
            new BasicNameValuePair("client_id", model.getSettings().getClientID()),
            new BasicNameValuePair("client_secret", model.getSettings().getClientSecret()),
            new BasicNameValuePair("redirect_uri", OauthUtils.getRedirectUrl(port)),
            new BasicNameValuePair("grant_type", "authorization_code")
            );
        try {

            final HttpEntity entity =
                new UrlEncodedFormEntity(nvps, LanternConstants.UTF8);
            post.setEntity(entity);

            log.debug("About to execute post!");
            final HttpResponse response = httpClient.execute(post);

            final StatusLine line = response.getStatusLine();
            log.debug("Got response status: {}", line);
            final HttpEntity responseEntity = response.getEntity();
            final String body = IOUtils.toString(responseEntity.getContent(), 
                    Charsets.UTF_8);
            EntityUtils.consume(responseEntity);
            
            final int statusCode = line.getStatusCode();
            if (statusCode < 200 || statusCode > 299) {
                final String msg = 
                        "Unexpected status code: "+statusCode+ " with body "+body;
                log.error(msg);
                throw new IOException(msg);
            }

            final Map<String, Object> oauthToks;
            try {
                oauthToks = JsonUtils.OBJECT_MAPPER.readValue(body, Map.class);
            } catch (final JsonParseException e) {
                log.error("Could not parse JSON: "+body, e);
                throw e;
            } catch (final JsonMappingException e) {
                log.error("Could not map JSON: "+body, e);
                throw e;
            }
            log.debug("Got oath data: {}", oauthToks);
            return oauthToks;
        } finally {
            post.reset();
        }
    }

    private void redirectToDashboard(final HttpServletResponse resp) {
        final String dashboard = StaticSettings.getLocalEndpoint();
        try {
            resp.sendRedirect(dashboard);
            resp.flushBuffer();
        } catch (final IOException e) {
            log.info("Error redirecting to the dashboard?", e);
        }
    }
}
