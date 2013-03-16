package org.lantern;

import java.io.IOException;
import java.util.concurrent.atomic.AtomicLong;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.group.ChannelGroup;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.handler.codec.http.HttpRequest;
import org.lantern.state.Model;
import org.littleshoot.proxy.ProxyUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handler that relays traffic to another proxy, dispatching between
 * appropriate proxies depending on the type of request.
 */
public class DispatchingProxyRelayHandler extends SimpleChannelUpstreamHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final AtomicLong messagesReceived = new AtomicLong();

    private Channel browserToProxyChannel;

    private final ClientSocketChannelFactory clientChannelFactory;

    private final ChannelGroup channelGroup;

    private final Stats stats;

    private final Model model;

    private final ProxyTracker proxyTracker;

    private final LanternTrustStore trustStore;

    /**
     * Creates a new handler that reads incoming HTTP requests and dispatches
     * them to proxies as appropriate.
     *
     * @param clientChannelFactory The factory for creating outgoing channels
     * to external sites.
     * @param channelGroup Keeps track of channels to close on shutdown.
     */
    public DispatchingProxyRelayHandler(
        final ClientSocketChannelFactory clientChannelFactory,
        final ChannelGroup channelGroup,
        final Stats stats, final Model model, final ProxyTracker proxyTracker,
        final LanternTrustStore trustStore) {
        this.clientChannelFactory = clientChannelFactory;
        this.channelGroup = channelGroup;
        this.stats = stats;
        this.model = model;
        this.proxyTracker = proxyTracker;
        this.trustStore = trustStore;
    }

    /**
     * Creates new default request processors to avoid worrying about holding
     * state across calls.
     *
     * @return The processor.
     */
    private HttpRequestProcessor newRequestProcessor() {
        return new TcpHttpRequestProcessor(this.proxyTracker,
            this.clientChannelFactory, this.channelGroup, this.stats, 
            this.trustStore);
    }
    
    /**
     * Creates new default request processors to avoid worrying about holding
     * state across calls.
     *
     * @return The processor.
     */
    private HttpRequestProcessor newP2PRequestProcessor() {
        return new UdtHttpRequestProcessor(this.proxyTracker,
            this.channelGroup, this.stats, this.trustStore);
    }

    @Override
    public void messageReceived(final ChannelHandlerContext ctx,
        final MessageEvent me) throws IOException {
        messagesReceived.incrementAndGet();
        log.debug("Received {} total messages", messagesReceived);
        final HttpRequest request = (HttpRequest)me.getMessage();
        final String uri = request.getUri();
        log.debug("URI is: {}", uri);
        this.stats.incrementProxiedRequests();
        boolean processed = false;
        try {
            processed = newRequestProcessor().processRequest(
                browserToProxyChannel, ctx, request);
        } catch (final IOException e) {
            processed = newP2PRequestProcessor().processRequest(
                browserToProxyChannel, ctx, request);
        }
        if (!processed) {
            ProxyUtils.closeOnFlush(ctx.getChannel());
        }
    }

    private boolean useStandardProxies() {
        return this.model.getSettings().isUseCentralProxies() && 
            model.getSettings().isUseCloudProxies();
    }

    @Override
    public void channelOpen(final ChannelHandlerContext ctx,
        final ChannelStateEvent e) {
        log.debug("Got incoming channel");
        this.browserToProxyChannel = e.getChannel();
        this.channelGroup.add(this.browserToProxyChannel);
    }

    @Override
    public void channelClosed(final ChannelHandlerContext ctx,
        final ChannelStateEvent e) {
        log.debug("Got inbound channel closed. Closing outbound.");
        //this.trustedPeerRequestProcessor.close();
        //this.anonymousPeerRequestProcessor.close();
        //this.proxyRequestProcessor.close();
        //this.laeRequestProcessor.close();
    }

    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx,
        final ExceptionEvent e) throws Exception {
        log.info("Caught exception on INBOUND channel", e.getCause());
        ProxyUtils.closeOnFlush(this.browserToProxyChannel);
    }

}