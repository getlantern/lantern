package org.lantern.util;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.handler.traffic.GlobalTrafficShapingHandler;
import org.jboss.netty.util.Timer;
import org.lantern.LanternClientConstants;
import org.lantern.PeerFactory;
import org.lantern.Shutdownable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class GlobalLanternServerTrafficShapingHandler 
    extends GlobalTrafficShapingHandler implements Shutdownable {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final AtomicInteger connectedChannels = new AtomicInteger(0);
    
    private final AtomicInteger totalChannels = new AtomicInteger(0);

    private final ConcurrentHashMap<InetAddress, LanternTrafficCounterHandler> handlers =
            new ConcurrentHashMap<InetAddress, LanternTrafficCounterHandler>();

    private final PeerFactory peerFactory;

    @Inject
    public GlobalLanternServerTrafficShapingHandler(final Timer timer,
            final PeerFactory peerFactory) {
        super(timer, LanternClientConstants.SYNC_INTERVAL_SECONDS * 1000);
        this.peerFactory = peerFactory;
    }

    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent e) throws Exception {
        try {
            this.connectedChannels.incrementAndGet();
        } finally {
            // The message is then just passed to the next handler
            super.messageReceived(ctx, e);
        }
    }
    @Override
    public void channelConnected(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) throws Exception {
        log.debug("Global channel open...");
        try {
            this.connectedChannels.incrementAndGet();
            this.totalChannels.incrementAndGet();
            
            // We basically want to add separate traffic handlers per IP, and
            // we do that here. We have a new incoming socket and check for an
            // existing handler. If it's there, we use it. Otherwise we add and
            // use a new one.
            final InetSocketAddress isa = 
                (InetSocketAddress) ctx.getChannel().getRemoteAddress();
            final InetAddress address = isa.getAddress();
            
            final LanternTrafficCounterHandler newHandler = 
                    new LanternTrafficCounterHandler(timer, true);
            final LanternTrafficCounterHandler existingHandler =
                    handlers.putIfAbsent(address, newHandler);
            
            final LanternTrafficCounterHandler toUse;
            if (existingHandler == null) {
                toUse = newHandler;
                this.peerFactory.addIncomingPeer(isa.getAddress(), newHandler);
            } else {
                toUse = existingHandler;
            }
            ctx.getChannel().getPipeline().addFirst("trafficHandler", toUse);
        } finally {
            // The message is then just passed to the next handler
            super.channelConnected(ctx, e);
        }
    }
    
    @Override
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) throws Exception {
        log.debug("Got channel closed!");
        this.connectedChannels.decrementAndGet();
        super.channelClosed(ctx, e);
    }
    
    public boolean isConnected() {
        return connectedChannels.get() > 0;
    }

    public int getNumSockets() {
        return connectedChannels.get();
    }
    
    public int getNumSocketsTotal() {
        return this.totalChannels.get();
    }

    @Override
    public void stop() {
        for (final GlobalTrafficShapingHandler handler : this.handlers.values()) {
            handler.releaseExternalResources();
        }
        releaseExternalResources();
    }

}
