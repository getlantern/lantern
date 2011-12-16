package org.lantern;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.MalformedURLException;
import java.util.Map;

import javax.servlet.GenericServlet;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.lang.StringUtils;
import org.cometd.server.CometdServlet;
import org.eclipse.jetty.http.HttpStatus;
import org.eclipse.jetty.server.Connector;
import org.eclipse.jetty.server.Request;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.handler.ContextHandlerCollection;
import org.eclipse.jetty.server.handler.HandlerList;
import org.eclipse.jetty.server.handler.ResourceHandler;
import org.eclipse.jetty.server.nio.SelectChannelConnector;
import org.eclipse.jetty.servlet.FilterHolder;
import org.eclipse.jetty.servlet.FilterMapping;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;
import org.eclipse.jetty.servlets.CrossOriginFilter;
import org.eclipse.jetty.util.resource.Resource;
import org.eclipse.jetty.util.thread.QueuedThreadPool;
import org.littleshoot.util.IoUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Launcher and secure path handler for Jetty.
 */
public class JettyLauncher {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final String secureBase = "";
        //"/"+String.valueOf(LanternHub.secureRandom().nextLong());

    private final int randomPort = LanternUtils.randomPort();
    
    private final String fullBasePath = 
        "http://localhost:"+randomPort+secureBase;
    
    private Server server = new Server();

    public void start() {
        final QueuedThreadPool qtp = new QueuedThreadPool();
        qtp.setMinThreads(5);
        qtp.setMaxThreads(200);
        server.setThreadPool(qtp);
        final String apiName = "Lantern-API";
        final ContextHandlerCollection contexts = 
            new ContextHandlerCollection();
        
        final ServletContextHandler api = newContext("/", apiName);
        //final ServletContextHandler api = newContext(secureBase, apiName);
        contexts.addHandler(api);

        api.setResourceBase("viz/skel");
        
        server.setHandler(contexts);
        server.setStopAtShutdown(true);
        
        final SelectChannelConnector connector = 
            new SelectChannelConnector();
        connector.setPort(randomPort);
        connector.setMaxIdleTime(120000);
        connector.setLowResourcesMaxIdleTime(60000);
        connector.setLowResourcesConnections(20000);
        connector.setAcceptQueueSize(5000);
        
        // TODO: Make sure this works on Linux!!
        connector.setHost("127.0.0.1");
        connector.setName(apiName);
        
        this.server.setConnectors(new Connector[]{connector});

        final CometdServlet cometdServlet = new CometdServlet();
        //final ServletConfig config = new ServletConfig
        //cometdServlet.init(config);
        final ServletHolder cometd = new ServletHolder(cometdServlet);
        cometd.setInitParameter("jsonContext", "org.cometd.server.JacksonJSONContextServer");
        cometd.setInitOrder(1);
        api.addServlet(cometd, "/cometd/*");
        
        final class ConfigServlet extends GenericServlet {

            private static final long serialVersionUID = -2633162671596490471L;

            @Override
            public void service(final ServletRequest req, 
                final ServletResponse res)
                throws ServletException, IOException {
                final String json = LanternHub.config().configAsJson();
                final byte[] raw = json.getBytes("UTF-8");
                res.setContentLength(raw.length);
                res.setContentType("application/json");
                res.getOutputStream().write(raw);
            }
            
        }
        final ServletHolder config = new ServletHolder(new ConfigServlet());
        config.setInitOrder(3);
        api.addServlet(config, "/config");
        
        final ServletHolder bayeux = new ServletHolder(BayeuxInitializer.class);
        bayeux.setInitParameter("jsonContext", "org.cometd.server.JacksonJSONContextServer");
        bayeux.setInitOrder(2);
        api.getServletHandler().addServlet(bayeux);
        
        api.addServlet("org.eclipse.jetty.servlet.DefaultServlet", "/");
        
        api.addFilter(new FilterHolder(CrossOriginFilter.class), "/cometd/*", 
            FilterMapping.REQUEST);
        
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
    
    private ServletContextHandler newContext(final String path,
        final String name) {
        final ServletContextHandler context = 
            new ServletContextHandler(ServletContextHandler.SESSIONS);
        
        final Map<String, String> params = context.getInitParams();
        params.put("org.eclipse.jetty.servlet.Default.gzip", "false");
        params.put("org.eclipse.jetty.servlet.Default.welcomeServlets", "false");
        params.put("org.eclipse.jetty.servlet.Default.dirAllowed", "false");
        params.put("org.eclipse.jetty.servlet.Default.aliases", "false");
        params.put("jsonContext", "org.cometd.server.JacksonJSONContextServer");
        context.setContextPath(path);
        context.setConnectorNames(new String[] {name});
        return context;
    }
    
    public void setup() {
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
            final boolean isGet = request.getMethod().equalsIgnoreCase("GET");
            final boolean isPost = request.getMethod().equalsIgnoreCase("POST");
            final String json;
            if (stripped.startsWith("/setConfig")) {
                final Map<String, String> args = LanternUtils.toParamMap(request);
                json = LanternHub.config().setConfig(args);
            } else if (stripped.startsWith("/config")) {
                if (isGet) {
                    json = LanternHub.config().configAsJson();
                } else { close(baseRequest, response); return;}
            } else if (stripped.startsWith("/whitelist")) {
                if (isGet) {
                    json = LanternHub.config().whitelist();
                } else { close(baseRequest, response); return;}
            } else if (stripped.startsWith("/roster")) {
                if (isGet) {
                    json = LanternHub.config().roster();
                } else { close(baseRequest, response); return;}
            } else if (stripped.startsWith("/addToWhitelist")) {
                final String site = request.getParameter("site");
                if (StringUtils.isBlank(site)) {
                    error("contact param required", baseRequest, response); 
                    return;
                }
                json = LanternHub.config().addToWhitelist(site);
            } else if (stripped.startsWith("/removeFromWhitelist")) {
                final String site = request.getParameter("site");
                if (StringUtils.isBlank(site)) {
                    error("contact param required", baseRequest, response);
                    return;
                }
                json = LanternHub.config().removeFromWhitelist(site);
            } else if (stripped.startsWith("/addToTrusted")) {
                final String contact = request.getParameter("contact");
                if (StringUtils.isBlank(contact)) {
                    error("contact param required", baseRequest, response);
                    return;
                }
                json = LanternHub.config().addToTrusted(contact);
            } else if (stripped.startsWith("/removeFromTrusted")) {
                final String contact = request.getParameter("contact");
                if (StringUtils.isBlank(contact)) {
                    error("contact param required", baseRequest, response);
                    return;
                }
                json = LanternHub.config().removeFromTrusted(contact);
            } else if (!isGet) {
                close(baseRequest, response); return;
            } else if (stripped.startsWith("/httpseverywhere")) {
                json = LanternHub.config().httpsEverywhere();
            } else if (stripped.startsWith("/stats")) {
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

    private String bodyToString(final HttpServletRequest request) 
        throws IOException {
        final InputStream is = request.getInputStream();
        final int cl = request.getContentLength();
        final byte[] body = IoUtils.toByteArray(is, cl);
        final String content = new String(body, "UTF-8");
        return content;
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

    private void close(final Request baseRequest, 
        final HttpServletResponse response) {
        baseRequest.setHandled(true);
        try {
            final OutputStream os = response.getOutputStream();
            os.close();
        } catch (final IOException e) {
            log.info("Could not close", e);
        }
    }
    
    private void error(final String msg, final Request baseRequest,
        final HttpServletResponse response) throws IOException {
        response.sendError(HttpStatus.BAD_REQUEST_400, msg);
        close(baseRequest, response);
    }
}

