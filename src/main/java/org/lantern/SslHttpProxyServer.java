package org.lantern;

import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.ServerSocketChannelFactory;
import org.jboss.netty.util.Timer;
import org.lantern.state.Model;
import org.lantern.util.GlobalLanternServerTrafficShapingHandler;
import org.littleshoot.proxy.HandshakeHandlerFactory;
import org.littleshoot.proxy.HttpFilter;
import org.littleshoot.proxy.HttpRequestFilter;
import org.littleshoot.proxy.HttpResponseFilters;

import com.google.common.base.Preconditions;
import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class SslHttpProxyServer extends StatsTrackingDefaultHttpProxyServer {

    private final Model model;

    @Inject
    public SslHttpProxyServer(final HttpRequestFilter requestFilter,
        final ClientSocketChannelFactory clientChannelFactory, 
        final Timer timer,
        final ServerSocketChannelFactory serverChannelFactory, 
        final HandshakeHandlerFactory handshakeHandlerFactory,
        final Stats stats, final Model model,
        final GlobalLanternServerTrafficShapingHandler serverTrafficHandler) {
        super(new HttpResponseFilters() {
            @Override
            public HttpFilter getFilter(String arg0) {
                return null;
            }
        }, null, requestFilter,
            clientChannelFactory, timer, serverChannelFactory, 
            handshakeHandlerFactory, stats,
            serverTrafficHandler);
        Preconditions.checkNotNull(model, "Model cannot be null");
        this.model = model;
    }

    @Override
    public int getPort() {
        return model.getSettings().getServerPort();
    }
}
