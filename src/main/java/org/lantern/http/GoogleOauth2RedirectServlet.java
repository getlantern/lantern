package org.lantern.http;

import java.io.IOException;
import java.util.Arrays;
import java.util.Collection;
import java.util.Map;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.lantern.Censored;
import org.lantern.LanternUtils;
import org.lantern.Proxifier;
import org.lantern.Proxifier.ProxyConfigurationError;
import org.lantern.ProxyService;
import org.lantern.XmppHandler;
import org.lantern.state.InternalState;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;
import org.lantern.state.ModelUtils;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.api.client.googleapis.auth.oauth2.GoogleBrowserClientRequestUrl;
import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets;
import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class GoogleOauth2RedirectServlet extends HttpServlet {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private static final long serialVersionUID = -957838028594747197L;

    private final XmppHandler handler;

    private final Model model;

    private final InternalState internalState;

    private final ModelIo modelIo;

    private final ProxyService proxifier;

    private final HttpClientFactory httpClientFactory;

    private final Censored censored;

    private final ModelUtils modelUtils;

    @Inject
    public GoogleOauth2RedirectServlet(final XmppHandler handler, 
        final Model model, final InternalState internalState,
        final ModelIo modelIo, final ProxyService proxifier,
        final HttpClientFactory httpClientFactory,
        final Censored censored, final ModelUtils modelUtils) {
        this.handler = handler;
        this.model = model;
        this.internalState = internalState;
        this.modelIo = modelIo;
        this.proxifier = proxifier;
        this.httpClientFactory = httpClientFactory;
        this.censored = censored;
        this.modelUtils = modelUtils;
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
    
    protected void processRequest(final HttpServletRequest req, 
        final HttpServletResponse resp) throws IOException {
        final String uri = req.getRequestURI();
        log.debug("Received URI: {}", uri);
        final Map<String, String> params = HttpUtils.toParamMap(req);
        log.debug("Params: {}", params);
        log.debug("Headers: {}", HttpUtils.toHeaderMap(req));
        log.debug("Query string: {}", req.getQueryString());
        if (this.censored.isCensored() || LanternUtils.isDevMode()) {
            try {
                proxifier.startProxying(true, Proxifier.PROXY_ALL);
            } catch (final ProxyConfigurationError e) {
                log.error("Could not start proxying", e);
            }
        }
        final String location = newGtalkOauthUrl();
        
        // We have to completely recreate the server each time because we
        // stop it and start it only when we need oauth callbacks. If we
        // attempt to restart a stopped server, things get funky.
        final GoogleOauth2CallbackServer server = 
            new GoogleOauth2CallbackServer(handler, model, this.internalState, 
                this.modelIo, this.proxifier, this.httpClientFactory, modelUtils);
        
        // Note that this call absolutely ensures the server is started.
        server.start();
        
        log.debug("Sending redirect to {}", location);
        resp.sendRedirect(location);
    }

    private String newGtalkOauthUrl() {
        try {
            
            final GoogleClientSecrets clientSecrets = 
                OauthUtils.loadClientSecrets();
            final Collection<String> scopes = 
                Arrays.asList(
                    "https://www.googleapis.com/auth/googletalk",
                    "https://www.googleapis.com/auth/userinfo.email",
                    "https://www.googleapis.com/auth/userinfo.profile");
            
            final GoogleBrowserClientRequestUrl gbc = 
                new GoogleBrowserClientRequestUrl(clientSecrets, 
                    OauthUtils.REDIRECT_URL, scopes);
            gbc.setApprovalPrompt("auto");
            gbc.setResponseTypes("code");
            final String url = gbc.build();
            
            log.debug("Sending redirect to URL: {}", url);
            return url;
        } catch (final IOException e) {
            throw new Error("Could not load oauth URL?", e);
        }
    }
}
