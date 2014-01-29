package org.lantern.http;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Map;

import javax.servlet.ServletException;
import javax.servlet.http.Cookie;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.cometd.server.CometdServlet;
import org.eclipse.jetty.http.HttpContent;
import org.eclipse.jetty.http.HttpHeaders;
import org.eclipse.jetty.server.Connector;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.handler.ContextHandlerCollection;
import org.eclipse.jetty.server.nio.SelectChannelConnector;
import org.eclipse.jetty.servlet.DefaultServlet;
import org.eclipse.jetty.servlet.FilterHolder;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;
import org.eclipse.jetty.servlets.CrossOriginFilter;
import org.eclipse.jetty.util.resource.Resource;
import org.eclipse.jetty.util.thread.QueuedThreadPool;
import org.lantern.BayeuxInitializer;
import org.lantern.LanternClientConstants;
import org.lantern.LanternConstants;
import org.lantern.LanternService;
import org.lantern.LanternUtils;
import org.lantern.Proxifier;
import org.lantern.state.Model;
import org.lantern.state.StaticSettings;
import org.lantern.state.SyncService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Launcher and secure path handler for Jetty.
 */
@Singleton
public class JettyLauncher implements LanternService {

    private final Logger log = LoggerFactory.getLogger(getClass());
        
    private final Server server = new Server();

    private final GoogleOauth2RedirectServlet redirectServlet;

    private final SyncService syncer;

    private final InteractionServlet interactionServlet;

    private final Model model;

    private final PhotoServlet photoServlet;

    @Inject
    public JettyLauncher(final SyncService syncer,
        final GoogleOauth2RedirectServlet redirectServlet,
        final InteractionServlet interactionServlet,
        final Model model, final PhotoServlet photoServlet) {
        this.syncer = syncer;
        this.redirectServlet = redirectServlet;
        this.interactionServlet = interactionServlet;
        this.model = model;
        this.photoServlet = photoServlet;
    }
    
    @Override
    public void start() {
        start(StaticSettings.getApiPort());
    }
    
    public void start(final int port) {
        final QueuedThreadPool qtp = new QueuedThreadPool();
        qtp.setMinThreads(5);
        qtp.setMaxThreads(200);
        qtp.setName("Lantern-Jetty-Thread");
        qtp.setDaemon(true);
        server.setThreadPool(qtp);
        final String apiName = "Lantern-API";
        final ContextHandlerCollection contexts = 
            new ContextHandlerCollection();

        final String prefix = StaticSettings.getPrefix();

        final ServletContextHandler contextHandler = newContext(prefix, apiName);

        contexts.addHandler(contextHandler);

        final String resourceBase;
        final String app = "./lantern-ui/app";
        final File appFile = new File(app);
        if (appFile.isDirectory()) {
            resourceBase = app;
        } else {
            resourceBase = "./lantern-ui";
        }
        contextHandler.setResourceBase(resourceBase);
        
        server.setHandler(contexts);
        server.setStopAtShutdown(true);
        
        final SelectChannelConnector connector = 
            new SelectChannelConnector();
        connector.setPort(port);
        connector.setMaxIdleTime(60 * 1000);
        connector.setLowResourcesMaxIdleTime(30 * 1000);
        connector.setLowResourcesConnections(2000);
        connector.setAcceptQueueSize(5000);


        if (this.model.getSettings().isBindToLocalhost()) {
            log.info("Binding to localhost");
            connector.setHost("127.0.0.1");
        } else {
            log.info("Binding to any address");
        }
        connector.setName(apiName);
        
        this.server.setConnectors(new Connector[]{connector});

        final CometdServlet cometdServlet = new LanternCometdServlet();

        final ServletHolder cometd = new ServletHolder(cometdServlet);
        cometd.setInitParameter("jsonContext", 
            "org.lantern.SettingsJSONContextServer");

        // An init order of -1 means to initialize upon first use.
        cometd.setInitOrder(-11);
        contextHandler.addServlet(cometd, "/cometd/*");
        
        final ServletHolder ds = new ServletHolder(new DefaultServlet() {

            private static final long serialVersionUID = 4335271390548389540L;

            // disable conditional responses
            @Override
            protected boolean passConditionalHeaders(HttpServletRequest request, HttpServletResponse response,
                                                     Resource resource, HttpContent content) throws IOException {
                return true;
            }

            @Override
            protected void doGet(HttpServletRequest req,
                final HttpServletResponse resp) throws ServletException, 
                IOException {
                final String uri = req.getPathInfo();
                log.debug("Processing get request for static file: "+uri);
                if (uri.startsWith("/proxy_on")) {
                    writeFileToResponse(resp, Proxifier.PROXY_ON);
                } else if (uri.startsWith("/proxy_off")) {
                    writeFileToResponse(resp, Proxifier.PROXY_OFF);
                } else if (uri.startsWith("/proxy_all")) {
                    writeFileToResponse(resp, Proxifier.PROXY_ALL);
                } else if (uri.startsWith("/proxy_google")) {
                    writeFileToResponse(resp, Proxifier.PROXY_GOOGLE);
                } else {
                    resp.addCookie(new Cookie("XSRF-TOKEN", model.getXsrfToken()));
                    if (!resp.containsHeader("Content-Security-Policy")) {
                        LanternUtils.addCSPHeader(resp);
                    }
                    super.doGet(req, resp);
                }
            }
        });
        // http://dev.eclipse.org/mhonarc/lists/jetty-users/msg01409.html
        ds.setInitParameter("cacheControl", "no-cache, no-store, must-revalidate");
        ds.setInitParameter("aliases", "true"); // follow symlinks

        ds.setInitOrder(1);
        contextHandler.addServlet(ds, "/*");
        
        if (this.redirectServlet != null) {
            final ServletHolder settings = new ServletHolder(redirectServlet);
            settings.setInitOrder(-1);
            contextHandler.addServlet(settings, "/oauth/");
        }
        
        if (this.interactionServlet != null) {
            final ServletHolder interactionServletHolder = 
                new ServletHolder(this.interactionServlet);
            interactionServletHolder.setInitOrder(-1);
            contextHandler.addServlet(interactionServletHolder, apiPath());
        }
        
        if (this.photoServlet != null) {
            final ServletHolder photo = new ServletHolder(this.photoServlet);
            photo.setInitOrder(-1);
            contextHandler.addServlet(photo, "/photo/*");
        }

        
        final BayeuxInitializer bi = new BayeuxInitializer(this.syncer);
        final ServletHolder bayeux = new ServletHolder(bi);
        bayeux.setInitParameter("jsonContext", 
            "org.cometd.server.JacksonJSONContextServer");
        bayeux.setInitOrder(-1);
        contextHandler.getServletHandler().addServlet(bayeux);
        
        if (!this.model.getSettings().isBindToLocalhost()) {
            final CrossOriginFilter filter = new CrossOriginFilter();
            final FilterHolder filterHolder = new FilterHolder(filter);
            //filterHolder.setInitParameter("allowedOrigins", "http://fiddle.jshell.net/");
            filterHolder.setInitParameter("allowedOrigins", "*");
        }

        final Thread serve = new Thread(new Runnable() {

            @Override
            public void run() {
                try {
                    server.start();
                    recordApiLocation(port, prefix);
                    server.join();
                } catch (final Exception e) {
                    log.error("Exception on HTTP server");
                }
            }
            
        }, "HTTP-Server-Thread");
        serve.setDaemon(true);
        serve.start();
    }


    private String apiPath() {
        return "/api/"+StringUtils.substringBeforeLast(LanternConstants.API_VERSION, ".")+"/*";
    }
    
    private void writeFileToResponse(final HttpServletResponse resp,
        final File file) {
        InputStream is = null;
        OutputStream os = null;
        try {
            is = new FileInputStream(file);
            os = resp.getOutputStream();
            resp.setContentLength((int) file.length());
            resp.setContentType("application/x-ns-proxy-autoconfig");
            IOUtils.copyLarge(is, os);
        } catch (final IOException e) {
            log.error("Could not write response?", e);
        } finally {
            IOUtils.closeQuietly(is);
            IOUtils.closeQuietly(os);
        }
    }

    @Override
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
    
    private void recordApiLocation(int port, String prefix) {
        String path = LanternClientConstants.CONFIG_DIR + "/api_location.txt";
        String location = String.format("http://localhost:%1$s%2$s", port,
                prefix);
        try {
            FileUtils.writeStringToFile(new File(path), location);
        } catch (Exception e) {
            log.warn(
                    "Unable to record API location, may impact automated test: "
                            + e.getMessage(), e);
        }
    }
}

