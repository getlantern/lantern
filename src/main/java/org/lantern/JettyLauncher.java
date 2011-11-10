package org.lantern;

import java.io.File;
import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URISyntaxException;
import java.security.SecureRandom;
import java.util.Map;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.eclipse.jetty.server.Handler;
import org.eclipse.jetty.server.Request;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.handler.DefaultHandler;
import org.eclipse.jetty.server.handler.HandlerList;
import org.eclipse.jetty.server.handler.ResourceHandler;
import org.eclipse.jetty.server.nio.SelectChannelConnector;
import org.eclipse.jetty.servlet.DefaultServlet;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.util.resource.FileResource;
import org.eclipse.jetty.util.resource.Resource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Launcher for Jetty.
 */
public class JettyLauncher {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final SecureRandom sr = new SecureRandom();

    private long randomLong = sr.nextLong();
    
    /**
     * Specialized servlet for file serving that simply uses the Jetty default
     * servlet with overriding the method for accessing resources based on the
     * request path.
     */
    private class FileServingServlet extends DefaultServlet {

        private static final long serialVersionUID = -6428591292336746514L;

        @Override
        public Resource getResource(final String pathInContext) {
            log.trace("Received request uri: {}", pathInContext);

            //final File file = LittleShootModule.getFileMapper().getFile(uri);
            
            final File file = new File(".");
            try {
                return new FileResource(file.toURI().toURL());
            } catch (final MalformedURLException e) {
                log.error("Could not create file resource", e);
            } catch (final IOException e) {
                log.error("Could not create file resource", e);
            } catch (final URISyntaxException e) {
                log.error("Could not create file resource", e);
            }
            return null;
        }
    }
    
    private class FileServingResourceHandler extends DefaultHandler {
        
        @Override public void handle(final String target, 
            final Request baseRequest, final HttpServletRequest request, 
            final HttpServletResponse response) 
            throws IOException, ServletException {
            super.handle(target, baseRequest, request, response);
        }
    }
    
    public void start() {
        
        final Server server = new Server();
        final SelectChannelConnector connector = new SelectChannelConnector();
        connector.setPort(8080);
        server.addConnector(connector);
 
        final ResourceHandler rh = new ResourceHandler();
        rh.setDirectoriesListed(false);
        //rh.setAliases(false);
        //rh.
        //rh.setWelcomeFiles(new String[]{ "lanternmap.html" });
        rh.setResourceBase("viz/skel");
 
        final HandlerList handlers = new HandlerList();
        handlers.setHandlers(
            new Handler[] { rh, new DefaultHandler() });
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
        try {
            Thread.sleep(200000);
        } catch (InterruptedException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
        
        /*
        final String apiName = "API";
        final String fsName = "FileServer";
        final ContextHandlerCollection contexts = 
            new ContextHandlerCollection();
        
        final ServletContextHandler api = newContext("/", apiName);
        contexts.addHandler(api);

        final ServletContextHandler files = newContext("/uri-res", fsName);
        contexts.addHandler(files);
        
        server.setHandler(contexts);
        server.setStopAtShutdown(true);
        
        final SelectChannelConnector apiConnector = 
            new SelectChannelConnector();
        apiConnector.setPort(ShootConstants.API_PORT);
        
        // TODO: Make sure this works on Linux!!
        apiConnector.setHost("127.0.0.1");
        apiConnector.setName(apiName);

        
        server.setConnectors(new Connector[]{apiConnector});
 
        api.addServlet(new ServletHolder(new AppCheckController()),"/api/client/appCheck");

        
        //api.addServlet(new ServletHolder(ds),"/favicon.ico");
        files.addServlet(new ServletHolder(new DefaultServlet()),"/*");
        
        startServer();
        
        //context.addServlet(new ServletHolder(),"");
         */
        
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
        //params.put("javax.servlet.include.request_uri", "true");
        context.setContextPath(path);
        context.setConnectorNames(new String[] {name});
        return context;
    }
    
    public static void main (final String[] args) {
        final JettyLauncher jl = new JettyLauncher();
        jl.start();
    }

    public void openBrowserWhenReady(String randomUrlBase) {
        // TODO Auto-generated method stub
        
    }
}
