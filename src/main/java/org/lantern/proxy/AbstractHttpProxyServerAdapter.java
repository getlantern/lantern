package org.lantern.proxy;

import org.lantern.LanternService;
import org.littleshoot.proxy.HttpProxyServer;
import org.littleshoot.proxy.HttpProxyServerBootstrap;

/**
 * Base class for objects that adapt {@link HttpProxyServer}s to the
 * {@link LanternService} API.
 */
public abstract class AbstractHttpProxyServerAdapter implements LanternService {
    private HttpProxyServerBootstrap bootstrap;
    protected HttpProxyServer server;
    private boolean running = false;

    protected void setBootstrap(HttpProxyServerBootstrap bootstrap) {
        this.bootstrap = bootstrap;
    }

    public HttpProxyServer getServer() {
        return server;
    }

    @Override
    synchronized public void start() {
        if (!running) {
            server = bootstrap.start();
            running = true;
        }
    }

    @Override
    synchronized public void stop() {
        if (server != null) {
            server.stop();
            running = false;
        }
    }
}
