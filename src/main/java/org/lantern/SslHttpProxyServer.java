package org.lantern;

import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.ServerSocketChannelFactory;
import org.jboss.netty.util.Timer;
import org.lantern.state.Model;
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
        final Stats stats, final Model model) {
        super(model.getSettings().getServerPort(),             
            new HttpResponseFilters() {
                @Override
                public HttpFilter getFilter(String arg0) {
                    return null;
                }
            }, null, requestFilter,
                clientChannelFactory, timer, serverChannelFactory, ksm, stats);
    }
}
