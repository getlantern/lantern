package org.lantern.util;

import java.util.concurrent.atomic.AtomicInteger;

import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.handler.traffic.GlobalTrafficShapingHandler;
import org.jboss.netty.util.Timer;
import org.lantern.LanternClientConstants;

public class Netty3LanternTrafficCounterHandler extends GlobalTrafficShapingHandler
    implements LanternTrafficCounter {

    private final AtomicInteger connectedChannels = new AtomicInteger(0);

    private long lastConnected = 0L;

    public Netty3LanternTrafficCounterHandler(final Timer timer, 
        final boolean connected) {
        super(timer, LanternClientConstants.SYNC_INTERVAL_SECONDS * 1000);
        
        // This means we're starting out connected, so make sure to increment
        // the channels and such. This will happen for incoming sockets
        // where this class is added dynamically after the initial connection.
        if (connected) {
            this.connectedChannels.incrementAndGet();
            this.lastConnected = System.currentTimeMillis();
        }
    }
    
    @Override
    public void channelConnected(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) throws Exception {
        try {
            this.connectedChannels.incrementAndGet();
        } finally {
            // The message is then just passed to the next handler
            super.channelConnected(ctx, e);
        }
    }
    
    @Override
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) throws Exception {
        try {
            this.connectedChannels.decrementAndGet();
            if (this.connectedChannels.get() == 0) {
                this.lastConnected = System.currentTimeMillis();
            }
        } finally {
            // The message is then just passed to the next handler
            super.channelClosed(ctx, e);
        }
    }
    
    @Override
    public boolean isConnected() {
        return connectedChannels.get() > 0;
    }

    @Override
    public int getNumSockets() {
        return connectedChannels.get();
    }

    @Override
    public long getLastConnected() {
        return this.lastConnected;
    }

    @Override
    public long getCumulativeReadBytes() {
        return trafficCounter.getCumulativeReadBytes();
    }

    @Override
    public long getCumulativeWrittenBytes() {
        return trafficCounter.getCumulativeWrittenBytes();
    }

    @Override
    public long getCurrentReadBytes() {
        return trafficCounter.getCurrentReadBytes();
    }

    @Override
    public long getCurrentWrittenBytes() {
        return trafficCounter.getCurrentWrittenBytes();
    }
}
