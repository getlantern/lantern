package org.lantern;

import java.io.IOException;
import java.net.MalformedURLException;
import java.security.SecureRandom;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.lang.StringUtils;
import org.eclipse.jetty.server.Handler;
import org.eclipse.jetty.server.Request;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.handler.DefaultHandler;
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
    
    private final SecureRandom sr = new SecureRandom();

    private final String secureBase = "/"+String.valueOf(sr.nextLong());

    private Server server = new Server();
    
    public void start() {
        final SelectChannelConnector connector = new SelectChannelConnector();
        connector.setPort(8080);
        server.addConnector(connector);
 
        final ResourceHandler rh = new FileServingResourceHandler();
        rh.setDirectoriesListed(false);
        rh.setAliases(false);
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
    }
    
    private final class FileServingResourceHandler extends ResourceHandler {
        
        @Override public void handle(final String target, 
            final Request baseRequest, final HttpServletRequest request, 
            final HttpServletResponse response) 
            throws IOException, ServletException {
            if (!target.startsWith(secureBase)) {
                response.getOutputStream().close();
                return;
            }
            
            super.handle(target, baseRequest, request, response);
        }
        
        @Override
        public Resource getResource(final String path) 
            throws MalformedURLException {
            final String stripped = 
                StringUtils.substringAfter(path, secureBase);
            return super.getResource(stripped);
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
        final String url = "http://localhost:8080"+secureBase+"/lanternmap.html";
        LanternUtils.browseUrl(url);
    }
    
    public static void main (final String[] args) {
        final JettyLauncher jl = LanternHub.jettyLauncher();
        System.out.println("Starting!!");
        jl.start();
        System.out.println("Opening browser!!");
        jl.openBrowserWhenReady();
        try {
            Thread.sleep(200000);
        } catch (InterruptedException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
    }

}
