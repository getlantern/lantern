package org.lantern;

import static org.jboss.netty.channel.Channels.pipeline;

import java.net.InetSocketAddress;
import java.util.Collection;

import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.handler.codec.http.HttpRequestDecoder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Factory for creating pipelines for incoming requests to our listening
 * socket.
 */
public class HttpServerPipelineFactory implements ChannelPipelineFactory {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final XmppHandler xmpp;

    private final Collection<String> whitelist;

    /**
     * Creates a new pipeline factory.
     * 
     * @param xmpp The class that deals with logging in to GChat.
     * @param whitelist The whitelist of sites to proxy.
     */
    public HttpServerPipelineFactory(final XmppHandler xmpp, 
        final Collection<String> whitelist) {
        this.xmpp = xmpp;
        this.whitelist = whitelist;
    }

    public ChannelPipeline getPipeline() {
        log.info("Using GAE proxy connection...");
        final InetSocketAddress proxy =
            new InetSocketAddress("laeproxy.appspot.com", 443);
            //new InetSocketAddress("127.0.0.1", 8080);
        final SimpleChannelUpstreamHandler handler = 
            new DispatchingProxyRelayHandler(proxy, xmpp, this.whitelist);
        final ChannelPipeline pipeline = pipeline();
        pipeline.addLast("decoder", new HttpRequestDecoder());
        pipeline.addLast("encoder", new ProxyHttpResponseEncoder());
        pipeline.addLast("handler", handler);
        return pipeline;
    }
}
