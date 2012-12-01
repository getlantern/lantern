package org.lantern.http;

import java.util.Map;

import org.eclipse.jetty.server.Connector;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.handler.ContextHandlerCollection;
import org.eclipse.jetty.server.nio.SelectChannelConnector;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;
import org.eclipse.jetty.util.thread.ExecutorThreadPool;
import org.lantern.LanternUtils;
import org.lantern.XmppHandler;
import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * This is a special server that runs on the port we have registered for
 * OAuth callbacks with Google. It should be started every time we know we
 * need OAuth (every time the OAuth redirect page is hit), and should stop it
 * as soon as the callback is done.
 */
public class GoogleOauth2CallbackServer {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Server server = new Server();
    
    private final int port = 7777;

    private final XmppHandler xmppHandler;

    private final Model model;
    
    public GoogleOauth2CallbackServer(final XmppHandler xmppHandler,
        final Model model) {
        this.xmppHandler = xmppHandler;
        this.model = model;
    }
    
    public void start() {
        // Note we unfortunately can't give our threads names using this
        // thread pool.
        server.setThreadPool(new ExecutorThreadPool(1));
        final String apiName = "Lantern-Oauth-Callback";
        final ContextHandlerCollection contexts = 
            new ContextHandlerCollection();
        
        final ServletContextHandler contextHandler = newContext("/", apiName);
        contexts.addHandler(contextHandler);

        
        server.setHandler(contexts);
        server.setStopAtShutdown(true);
        
        final SelectChannelConnector connector = 
            new SelectChannelConnector();
        log.info("Setting connector port for OAUTH to: {}", port);
        connector.setPort(port);
        connector.setMaxIdleTime(80 * 1000);
        connector.setLowResourcesMaxIdleTime(30 * 1000);
        connector.setLowResourcesConnections(100);
        connector.setHost("127.0.0.1");
        connector.setName(apiName);
        connector.setAcceptors(1);
        
        this.server.setConnectors(new Connector[]{connector});
        
        final ServletHolder oauth2callback = new ServletHolder(
            new GoogleOauth2CallbackServlet(this, this.xmppHandler, this.model));
        oauth2callback.setInitOrder(1);
        contextHandler.addServlet(oauth2callback, "/oauth2callback");
        
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
            
        }, "HTTP-Server-Oauth-Thread");
        serve.setDaemon(true);
        serve.start();
        
        log.info("About to wait for server....");
        LanternUtils.waitForServer(this.port);
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
        context.setContextPath(path);
        context.setConnectorNames(new String[] {name});
        return context;
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
}
