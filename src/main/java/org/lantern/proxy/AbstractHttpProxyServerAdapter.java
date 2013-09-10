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

    public AbstractHttpProxyServerAdapter(HttpProxyServerBootstrap bootstrap) {
        this.bootstrap = bootstrap;
    }

    public HttpProxyServer getServer() {
        return server;
    }

    @Override
    public void start() {
        server = bootstrap.start();
    }

    @Override
    public void stop() {
        server.stop();
    }
}
