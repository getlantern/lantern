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

    public Netty3LanternTrafficCounterHandler(final Timer timer) {
        super(timer, LanternClientConstants.SYNC_INTERVAL_SECONDS * 1000);
    }
    

    @Override
    public void incrementSockets() {
        // This is often necessary because this handler will be added
        // dynamically in connection events themselves, so otherwise it would
        // miss connections.
        this.connectedChannels.incrementAndGet();
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
