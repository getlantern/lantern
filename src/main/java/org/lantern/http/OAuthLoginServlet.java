package org.lantern.http;

import java.io.IOException;
import java.util.Map;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Servlet for logging the user in using OAuth.
 */
public class OAuthLoginServlet extends HttpServlet {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    /**
     * Generated serialization ID.
     */
    private static final long serialVersionUID = 7221978417173999841L;
    
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
        final HttpServletResponse resp) {
        final String uri = req.getRequestURI();
        log.info("Received URI: {}", uri);
        final Map<String, String> params = HttpUtils.toParamMap(req);
        log.info("Params: {}", params);
        final String token = params.get("token");
        if (StringUtils.isBlank(token)) {
            log.info("No token!!");
            HttpUtils.sendClientError(resp, "token argument required!");
            return;
        }
    }

}
