package org.lantern.http;

import java.io.IOException;
import java.util.Arrays;
import java.util.Collection;
import java.util.Map;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.lantern.Proxifier;
import org.lantern.XmppHandler;
import org.lantern.state.InternalState;
import org.lantern.state.Model;
import org.lantern.state.ModelIo;
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

    private final Proxifier proxifier;

    @Inject
    public GoogleOauth2RedirectServlet(final XmppHandler handler, 
        final Model model, final InternalState internalState,
        final ModelIo modelIo, final Proxifier proxifier) {
        this.handler = handler;
        this.model = model;
        this.internalState = internalState;
        this.modelIo = modelIo;
        this.proxifier = proxifier;
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
        proxifier.proxyGoogle();
        final String location = newGtalkOauthUrl();
        
        // We have to completely recreate the server each time because we
        // stop it and start it only when we need oauth callbacks. If we
        // attempt to restart a stopped server, things get funky.
        final GoogleOauth2CallbackServer server = 
            new GoogleOauth2CallbackServer(handler, model, 
                this.internalState, this.modelIo, this.proxifier);
        
        // Note that this call absolutely ensures the server is started.
        server.start();
        
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
