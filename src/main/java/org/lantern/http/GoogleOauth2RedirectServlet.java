package org.lantern.http;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Arrays;
import java.util.Collection;
import java.util.Map;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.io.IOUtils;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.utils.URIBuilder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.api.client.googleapis.auth.oauth2.GoogleBrowserClientRequestUrl;
import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets;
import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets.Details;
import com.google.api.client.json.jackson.JacksonFactory;
import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class GoogleOauth2RedirectServlet extends HttpServlet {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private static final long serialVersionUID = -957838028594747197L;

    private final GoogleOauth2CallbackServer server;

    @Inject
    public GoogleOauth2RedirectServlet(final GoogleOauth2CallbackServer server) {
        this.server = server;
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
        log.info("Received URI: {}", uri);
        final Map<String, String> params = HttpUtils.toParamMap(req);
        log.info("Params: {}", params);
        log.info("Headers: {}", HttpUtils.toHeaderMap(req));
        log.info("Query string: {}", req.getQueryString());
        final String location = newGtalkOauthUrl();
        
        // Note that this call absolutely ensures the server is started.
        this.server.start();
        
        resp.sendRedirect(location);
    }
    

    private String newGtalkOauthUrl() {
        InputStream is = null;
        try {
            is = new FileInputStream("client_secrets_installed.json");
            final GoogleClientSecrets clientSecrets =
                GoogleClientSecrets.load(new JacksonFactory(), is);
            final String redirectUrl = "http://localhost:7777/oauth2callback";
            final Collection<String> scopes = 
                Arrays.asList("https://www.googleapis.com/auth/googletalk");
            final GoogleBrowserClientRequestUrl gbc = 
                new GoogleBrowserClientRequestUrl(clientSecrets, redirectUrl, scopes);
            gbc.setApprovalPrompt("auto");
            gbc.setResponseTypes("code");
            final String url = gbc.build();
            
            log.info("Sending redirect to URL: {}", url);
            return url;
        } catch (final IOException e) {
            throw new Error("Could not load oauth URL?", e);
        } finally {
            IOUtils.closeQuietly(is);
        }
    }
    
    
    private String buildUri(final Details details) {
        final URIBuilder builder = new URIBuilder();

        builder.setScheme("https")
            .setHost("accounts.google.com")
            .setPath("/o/oauth2/auth")
            .setParameter("approval_prompt", "auto")
            .setParameter("client_id", details.getClientId())
            .setParameter("redirect_uri", "http://localhost:7777/oauth2callback")
            .setParameter("response_type", "code")
            .setParameter("scope", "" +
                "https://www.googleapis.com/auth/googletalk " +
                "https://www.googleapis.com/auth/userinfo.email");

        final URI uri;
        try {
            uri = builder.build();
        } catch (final URISyntaxException e) {
            throw new Error("Could not build URI?", e);
        }

        final HttpGet get = new HttpGet(uri);
        return get.getURI().toASCIIString();
    }
}
