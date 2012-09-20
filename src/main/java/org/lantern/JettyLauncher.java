package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.Map;

import javax.servlet.GenericServlet;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang3.SystemUtils;
import org.cometd.server.CometdServlet;
import org.eclipse.jetty.server.Connector;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.handler.ContextHandlerCollection;
import org.eclipse.jetty.server.nio.SelectChannelConnector;
import org.eclipse.jetty.servlet.DefaultServlet;
import org.eclipse.jetty.servlet.FilterHolder;
import org.eclipse.jetty.servlet.FilterMapping;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;
import org.eclipse.jetty.servlets.CrossOriginFilter;
import org.eclipse.jetty.util.thread.QueuedThreadPool;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Launcher and secure path handler for Jetty.
 */
public class JettyLauncher {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final String secureBase = "";
        //"/"+String.valueOf(LanternHub.secureRandom().nextLong());

    private final int port = LanternHub.settings().getApiPort();

    private final String fullBasePath = 
        "http://localhost:"+port+secureBase;
    
    private final Server server = new Server();

    private final File resourceBaseFile;

    public JettyLauncher() {
        final File staticdir = 
            new File(LanternHub.settings().getUiDir(), "assets");
        
        if (staticdir.isDirectory()) {
            this.resourceBaseFile = staticdir;
        } else {
            this.resourceBaseFile = new File("assets");
        }
    }
    
    public void start() {
        final QueuedThreadPool qtp = new QueuedThreadPool();
        qtp.setMinThreads(5);
        qtp.setMaxThreads(200);
        qtp.setName("Lantern-Jetty-Thread");
        qtp.setDaemon(true);
        server.setThreadPool(qtp);
        final String apiName = "Lantern-API";
        final ContextHandlerCollection contexts = 
            new ContextHandlerCollection();
        
        final ServletContextHandler contextHandler = newContext("/", apiName);
        //final ServletContextHandler api = newContext(secureBase, apiName);
        contexts.addHandler(contextHandler);

        contextHandler.setResourceBase(this.resourceBaseFile.toString());
        
        server.setHandler(contexts);
        server.setStopAtShutdown(true);
        
        final SelectChannelConnector connector = 
            new SelectChannelConnector();
        log.info("Setting connector port for API to: {}", port);
        connector.setPort(port);
        connector.setMaxIdleTime(60 * 1000);
        connector.setLowResourcesMaxIdleTime(30 * 1000);
        connector.setLowResourcesConnections(2000);
        connector.setAcceptQueueSize(5000);
        //connector.setThreadPool(new QueuedThreadPool(20));
        
        if (LanternHub.settings().isBindToLocalhost()) {
            // TODO: Make sure this works on Linux!!
            log.info("Binding to localhost");
            connector.setHost("127.0.0.1");
        } else {
            log.info("Binding to any address");
        }
        connector.setName(apiName);
        
        this.server.setConnectors(new Connector[]{connector});

        final CometdServlet cometdServlet = new CometdServlet();
        //final ServletConfig config = new ServletConfig
        //cometdServlet.init(config);
        final ServletHolder cometd = new ServletHolder(cometdServlet);
        cometd.setInitParameter("jsonContext", 
            "org.lantern.SettingsJSONContextServer");
        //cometd.setInitParameter("transports", 
        //    "org.cometd.websocket.server.WebSocketTransport");
        cometd.setInitOrder(1);
        contextHandler.addServlet(cometd, "/cometd/*");
        
        final class ConfigServlet extends GenericServlet {
            private static final long serialVersionUID = -2633162671596490471L;
            @Override
            public void service(final ServletRequest req, 
                final ServletResponse res)
                throws ServletException, IOException {
                final Settings settings = LanternHub.settings();
                final String json = LanternUtils.jsonify(settings, Settings.UIStateSettings.class);
                final byte[] raw = json.getBytes("UTF-8");
                res.setContentLength(raw.length);
                res.setContentType("application/json; charset=UTF-8");
                res.getOutputStream().write(raw);
            }
        }
        
        final class SettingsServlet extends HttpServlet {

            private static final long serialVersionUID = -2647134475684088881L;

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
                LanternHub.api().changeSetting(req, resp);
            }
        }
        
        final class ApiServlet extends HttpServlet {

            private static final long serialVersionUID = -4199110396383838768L;

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
                LanternHub.api().processCall(req, resp);
            }
        }
        
        
        final ServletHolder ds = new ServletHolder(new DefaultServlet() {

            private static final long serialVersionUID = 4335271390548389540L;

            @Override
            protected void doGet(final HttpServletRequest req, 
                final HttpServletResponse resp) throws ServletException, 
                IOException {
                final String userAgent = req.getParameter(HttpHeaders.Names.USER_AGENT);
                if (StringUtils.isNotBlank(userAgent) && userAgent.contains("MSIE 6")) {
                    // If the user is running IE6, we want to close the dashboard and
                    // pop up a message telling them to download a newer version.
                    
                    // NOTE: The above will match older Opera versions too, but we don't
                    // support those either.
                    final String url;
                    if (SystemUtils.IS_OS_WINDOWS_XP) {
                        url = "http://windows.microsoft.com/en-US/internet-explorer/downloads/ie-8";
                    } else {
                        url = "http://windows.microsoft.com/en-US/internet-explorer/downloads/ie";
                    }
                    
                    LanternHub.jettyLauncher().stop();
                    
                    LanternHub.dashboard().showMessage("Unsupported Browser", 
                        "We're sorry, but Lantern requires Internet Explorer 8 or " +
                        "above. Lantern will open the download page for you " +
                        "automatically. After downloading and installing Internet " +
                        "Explorer 8, you can restart Lantern.");
                    
                    LanternUtils.browseUrl(url);
                    System.exit(0);
                }
                final String uri = req.getRequestURI();
                final String onPath = "/proxy_on.pac";
                final String offPath = "/proxy_off.pac";
                final String allPath = "/proxy_all.pac";
                if (uri.startsWith("/proxy_on") && !uri.equals(onPath)) {
                    resp.sendRedirect(onPath);
                } else if (uri.startsWith("/proxy_off") && !uri.equals(offPath)) {
                    resp.sendRedirect(offPath);
                } else if (uri.startsWith("/proxy_all") && !uri.equals(allPath)) {
                    resp.sendRedirect(allPath);
                } else {
                    super.doGet(req, resp);
                }
            }
        });
        if (LanternHub.settings().isCache()) {
            ds.setInitParameter("cacheControl", "private, max-age=" +
                LanternConstants.DASHCACHE_MAXAGE);
        } else {
            ds.setInitParameter("cacheControl", "no-cache");
        }
        ds.setInitParameter("aliases", "true");

        ds.setInitOrder(3);
        contextHandler.addServlet(ds, "/*");
        
        final ServletHolder settings = new ServletHolder(new SettingsServlet());
        settings.setInitOrder(3);
        contextHandler.addServlet(settings, "/settings/*");
        
        final ServletHolder apiServlet = new ServletHolder(new ApiServlet());
        apiServlet.setInitOrder(3);
        contextHandler.addServlet(apiServlet, "/api/*");
        
        final ServletHolder photoServlet = new ServletHolder(new PhotoServlet());
        photoServlet.setInitOrder(3);
        contextHandler.addServlet(photoServlet, "/photo/*");
        
        final ServletHolder config = new ServletHolder(new ConfigServlet());
        config.setInitOrder(3);
        contextHandler.addServlet(config, "/config");
        
        final ServletHolder bayeux = new ServletHolder(BayeuxInitializer.class);
        bayeux.setInitParameter("jsonContext", 
            "org.cometd.server.JacksonJSONContextServer");
        bayeux.setInitOrder(2);
        contextHandler.getServletHandler().addServlet(bayeux);
        
        if (!LanternHub.settings().isBindToLocalhost()) {
            final CrossOriginFilter filter = new CrossOriginFilter();
            final FilterHolder filterHolder = new FilterHolder(filter);
            //filterHolder.setInitParameter("allowedOrigins", "http://fiddle.jshell.net/");
            filterHolder.setInitParameter("allowedOrigins", "*");
            contextHandler.addFilter(filterHolder, secureBase + "/cometd/*", 
                FilterMapping.REQUEST);
            contextHandler.addFilter(filterHolder, secureBase + "/api/*", 
                    FilterMapping.REQUEST);
            contextHandler.addFilter(filterHolder, secureBase + "/settings/*", 
                    FilterMapping.REQUEST);
            contextHandler.addFilter(filterHolder, secureBase + "/photo/*", 
                    FilterMapping.REQUEST);
        }
        
        //new SyncService(new SwtJavaScriptSyncStrategy());
        
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
    

    public void stop() {
        log.info("Stopping Jetty server...");
        try {
            this.server.stop();
        } catch (final Exception e) {
            log.info("Exception stopping server", e);
        }
        log.info("Done stopping Jetty server...");
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

    public void openBrowserWhenReady() {
        while(!server.isStarted()) {
            try {
                Thread.sleep(100);
            } catch (final InterruptedException e) {
                log.info("Interrupted?");
            }
        }
        log.info("Server is running. Opening browser...");
        LanternHub.dashboard().openBrowser();
    }
    
    public File getResourceBaseFile() {
        return resourceBaseFile;
    }
    
    public int getPort() {
        return port;
    }
}

