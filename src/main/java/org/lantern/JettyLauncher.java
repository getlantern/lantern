package org.lantern;

import java.io.IOException;
import java.io.OutputStream;
import java.net.MalformedURLException;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.lang.StringUtils;
import org.eclipse.jetty.server.Request;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.handler.HandlerList;
import org.eclipse.jetty.server.handler.ResourceHandler;
import org.eclipse.jetty.server.nio.SelectChannelConnector;
import org.eclipse.jetty.util.resource.Resource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Launcher and secure path handler for Jetty.
 */
public class JettyLauncher {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final String secureBase = 
        "/"+String.valueOf(LanternHub.secureRandom().nextLong());

    private final int randomPort = LanternUtils.randomPort();
    
    private final String fullBasePath = 
        "http://localhost:"+randomPort+secureBase;
    
    private Server server = new Server();

    public void start() {
        final SelectChannelConnector connector = new SelectChannelConnector();
        connector.setHost("127.0.0.1");
        connector.setPort(randomPort);
        connector.setMaxIdleTime(60000);
        server.addConnector(connector);

        final ResourceHandler rh = new FileServingResourceHandler();
        rh.setDirectoriesListed(false);
        rh.setAliases(false);
        rh.setResourceBase("viz/skel");
 
        final HandlerList handlers = new HandlerList();
        handlers.addHandler(new ApiResourceHandler());
        handlers.addHandler(rh);
        server.setHandler(handlers);

        final Thread serve = new Thread(new Runnable() {

            @Override
            public void run() {
                try {
                    server.start();
                    server.join();
                } catch (final Exception e) {
                    log.error("Exception on HTTP server");
                }
            }
            
        }, "HTTP-Server-Thread");
        serve.setDaemon(true);
        serve.start();
    }
    
    public boolean isSecureRequest(final String target, 
        final Request baseRequest, final HttpServletRequest request, 
        final HttpServletResponse response) 
        throws IOException {
        log.info("Processing request: {}", target);
        /*
        final String code = LanternUtils.getStringProperty("google_oath");
        if (StringUtils.isBlank(code)) {
            final String oauth = OAuth.getAuthUrl(fullBasePath);
            log.info("Redirecting to OAuth: "+oauth);
            response.sendRedirect(oauth);
            baseRequest.setHandled(true);
            return false;
        }
        */
        if (!target.startsWith(secureBase)) {
            // This can happen quite often, as the pages we serve 
            // themselves don't know about the secure base. As long as
            // they get referred by the secure base, however, we're all 
            // good.
            log.info("Got request without secure base -- " +
                "probably has referer though");
            final String referer = request.getHeader("Referer");
            if (referer == null || !referer.startsWith(fullBasePath)) {
                log.info("Got request with bad referer: {} with target {}", 
                    referer, target);
                baseRequest.setHandled(true);
                response.getOutputStream().close();
                return false;
            }
        }
        return true;
    }
    
    private final class FileServingResourceHandler extends ResourceHandler {
        
        @Override public void handle(final String target, 
            final Request baseRequest, final HttpServletRequest request, 
            final HttpServletResponse response) 
            throws IOException, ServletException {
            if (isSecureRequest(target, baseRequest, request, response)) {
                super.handle(target, baseRequest, request, response);
            }
        }
        
        @Override
        public Resource getResource(final String path) 
            throws MalformedURLException {
            // Note it's impossible to get here unless the request already
            // passed the above security checks.
            if (!path.startsWith(secureBase)) {
                log.info("Requesting unstripped: {}", path);
                return super.getResource(path);
            }
            final String stripped = 
                StringUtils.substringAfter(path, secureBase);
            log.info("Requesting stripped: {}", stripped);
            return super.getResource(stripped);
        }
    }
    
    private final class ApiResourceHandler extends ResourceHandler {
        
        @Override public void handle(final String target, 
            final Request baseRequest, final HttpServletRequest request, 
            final HttpServletResponse response) 
            throws IOException, ServletException {
            log.info("Got request on API");
            if (!isSecureRequest(target, baseRequest, request, response)) {
                return;
            } 
            final String stripped;
            if (target.startsWith(secureBase)) {
                stripped = StringUtils.substringAfter(target, secureBase);
            } else {
                stripped = target;
            }
            log.info("Stripped is: {}", stripped);
            final String json;
            if (stripped.startsWith("/stats")) {
                json = LanternHub.statsTracker().toJson();
            } else if (stripped.startsWith("/oni")) {
                json = LanternHub.statsTracker().oniJson();
            } else if (stripped.startsWith("/country/")) {
                final String country;
                if (stripped.contains("?")) {
                    country = StringUtils.substringBetween(stripped, "/country/", "?");
                } else {
                    country = StringUtils.substringAfter(stripped, "/country/");
                }
                json = LanternHub.statsTracker().countryData(country);
            } else if (stripped.startsWith("/googleContentRemovalProductReason")) {
                json = LanternHub.statsTracker().googleContentRemovalProductReason();
            } else if (stripped.startsWith("/googleContentRemovalRequests")) {
                json = LanternHub.statsTracker().googleContentRemovalRequests();
            } else if (stripped.startsWith("/googleUserRequests")) {
                json = LanternHub.statsTracker().googleUserRequests();
            } else if (stripped.startsWith("/googleRemovalByProductRequests")) {
                json = LanternHub.statsTracker().googleRemovalByProductRequests();
            } else {
                log.info("Not an API call - passing to next handler");
                return;
            }
            final String responseString;
            final String functionName = request.getParameter("callback");
            if (StringUtils.isBlank(functionName)) {
                responseString = json;
                response.setContentType("application/json");
            } else {
                responseString = functionName + "(" + json + ");";
                response.setContentType("text/javascript");
            }
            
            response.setStatus(HttpServletResponse.SC_OK);
            
            final byte[] content = responseString.getBytes("UTF-8");
            response.setContentLength(content.length);

            final OutputStream os = response.getOutputStream();

            os.write(content);
            os.flush();
            baseRequest.setHandled(true);
        }
    }
    

    public void openBrowserWhenReady() {
        while(!server.isRunning()) {
            try {
                Thread.sleep(200);
            } catch (final InterruptedException e) {
                log.info("Interrupted?");
            }
        }
        log.info("Server is running!");
        final String url = fullBasePath + "/lanternmap.html";
        LanternUtils.browseUrl(url);
    }
}
