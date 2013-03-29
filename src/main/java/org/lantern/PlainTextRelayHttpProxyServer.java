package org.lantern;

import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.ServerSocketChannelFactory;
import org.jboss.netty.util.Timer;
import org.lantern.util.GlobalLanternServerTrafficShapingHandler;
import org.littleshoot.proxy.HandshakeHandlerFactory;
import org.littleshoot.proxy.HttpFilter;
import org.littleshoot.proxy.HttpRequestFilter;
import org.littleshoot.proxy.HttpResponseFilters;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class PlainTextRelayHttpProxyServer extends StatsTrackingDefaultHttpProxyServer {

    @Inject
    public PlainTextRelayHttpProxyServer(final HttpRequestFilter requestFilter,
        final ClientSocketChannelFactory clientChannelFactory, 
        final Timer timer,
        final ServerSocketChannelFactory serverChannelFactory, 
        final HandshakeHandlerFactory handshakeHandlerFactory,
        final Stats stats,
        final GlobalLanternServerTrafficShapingHandler serverTrafficHandler) {
        super(LanternUtils.PLAINTEXT_LOCALHOST_PROXY_PORT,
            new HttpResponseFilters() {
                @Override
                public HttpFilter getFilter(String arg0) {
                    return null;
                }
            }, null, requestFilter, clientChannelFactory, timer, 
            serverChannelFactory, handshakeHandlerFactory, stats, 
            serverTrafficHandler);
    }
}
