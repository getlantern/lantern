package org.lantern;

import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.ServerSocketChannelFactory;
import org.jboss.netty.util.Timer;
import org.lantern.state.Model;
import org.lantern.util.GlobalLanternServerTrafficShapingHandler;
import org.littleshoot.proxy.HttpFilter;
import org.littleshoot.proxy.HttpRequestFilter;
import org.littleshoot.proxy.HttpResponseFilters;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class SslHttpProxyServer extends StatsTrackingDefaultHttpProxyServer {

    @Inject
    public SslHttpProxyServer(final HttpRequestFilter requestFilter,
        final ClientSocketChannelFactory clientChannelFactory, 
        final Timer timer,
        final ServerSocketChannelFactory serverChannelFactory, 
        final LanternKeyStoreManager ksm,
        final Stats stats, final Model model,
        final GlobalLanternServerTrafficShapingHandler serverTrafficHandler) {
        this(model.getSettings().getServerPort(),requestFilter,
                clientChannelFactory, timer, serverChannelFactory, ksm, stats,
                serverTrafficHandler);
    }
    
    public SslHttpProxyServer(final int port, 
        final HttpRequestFilter requestFilter,
        final ClientSocketChannelFactory clientChannelFactory, 
        final Timer timer,
        final ServerSocketChannelFactory serverChannelFactory, 
        final LanternKeyStoreManager ksm,
        final Stats stats, 
        final GlobalLanternServerTrafficShapingHandler serverTrafficHandler) {
        super(port,             
            new HttpResponseFilters() {
                @Override
                public HttpFilter getFilter(String arg0) {
                    return null;
                }
            }, null, requestFilter,
                clientChannelFactory, timer, serverChannelFactory, ksm, stats,
                serverTrafficHandler);
    }
}
