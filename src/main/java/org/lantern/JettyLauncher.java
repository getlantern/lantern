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

    private final int randomPort = LanternUtils.randomPort();
    
    private final String fullBasePath = 
        "http://localhost:"+randomPort+secureBase;
    
    private Server server = new Server();

    public void start() {
        final SelectChannelConnector connector = new SelectChannelConnector();
        connector.setHost("127.0.0.1");
        connector.setPort(randomPort);
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
                // This can happen quite often, as the pages we serve 
                // themselves don't know about the secure base. As long as
                // they get referred by the secure base, however, we're all 
                // good.
                log.info("Got request without secure base!!");
                final String referer = request.getHeader("Referer");
                if (referer == null || !referer.startsWith(fullBasePath)) {
                    log.info("Got request with bad referer: {} with target {}", 
                        referer, target);
                    response.getOutputStream().close();
                    return;
                }
            }
            
            super.handle(target, baseRequest, request, response);
        }
        
        @Override
        public Resource getResource(final String path) 
            throws MalformedURLException {
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
    

    public void openBrowserWhenReady() {
        while(!server.isRunning()) {
            try {
                Thread.sleep(200);
            } catch (final InterruptedException e) {
                log.info("Interrupted?");
            }
        }
        final String url = fullBasePath + "/lanternmap.html";
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
        }
    }

}
