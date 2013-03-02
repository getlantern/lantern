package org.lantern.util;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.handler.traffic.GlobalTrafficShapingHandler;
import org.jboss.netty.util.Timer;
import org.lantern.LanternClientConstants;
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

    private final ConcurrentHashMap<InetAddress, LanternTrafficCounterHandler> handlers =
            new ConcurrentHashMap<InetAddress, LanternTrafficCounterHandler>();
        
    @Inject
    public GlobalLanternServerTrafficShapingHandler(final Timer timer) {
        super(timer, LanternClientConstants.SYNC_INTERVAL_SECONDS * 1000);
    }

    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) throws Exception {
        log.debug("Got global channel open!");
        this.connectedChannels.incrementAndGet();
        
        // We basically want to add separate traffic handlers per IP, and
        // we do that here. We have a new incoming socket and check for an
        // existing handler. If it's there, we use it. Otherwise we add and
        // use a new one.
        final InetSocketAddress isa = 
            (InetSocketAddress) ctx.getChannel().getRemoteAddress();
        final InetAddress address = isa.getAddress();
        final LanternTrafficCounterHandler handler = 
            new LanternTrafficCounterHandler(timer);
        final LanternTrafficCounterHandler existing = 
                handlers.putIfAbsent(address, handler);
        
        final LanternTrafficCounterHandler toUse;
        if (existing == null) {
            // OK, so this a new IP address. We need to also add a new Peer
            // here, and we'll give it our traffic handler!
            toUse = handler;
        } else {
            toUse = existing;
        }
        
        log.debug("Adding traffic handler to pipeline");
        ctx.getChannel().getPipeline().addFirst("trafficHandler", toUse);
    }
    
    @Override
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) throws Exception {
        log.debug("Got channel closed!");
        this.connectedChannels.decrementAndGet();
    }
    
    public boolean isConnected() {
        return connectedChannels.get() > 0;
    }

    public int getNumSockets() {
        return connectedChannels.get();
    }
    

    @Override
    public void stop() {
        for (final GlobalTrafficShapingHandler handler : this.handlers.values()) {
            handler.releaseExternalResources();
        }
        releaseExternalResources();
    }

}
