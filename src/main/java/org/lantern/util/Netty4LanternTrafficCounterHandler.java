package org.lantern.util;

import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelPipeline;
import io.netty.channel.ChannelStateHandler;
import io.netty.handler.traffic.GlobalTrafficShapingHandler;

import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.atomic.AtomicInteger;

import org.lantern.LanternClientConstants;

public class Netty4LanternTrafficCounterHandler extends GlobalTrafficShapingHandler 
    implements LanternTrafficCounter {

    private final AtomicInteger connectedChannels = new AtomicInteger(0);

    private long lastConnected = 0L;

    public Netty4LanternTrafficCounterHandler(
        final ScheduledExecutorService executor, final boolean connected) {
        super(executor, LanternClientConstants.SYNC_INTERVAL_SECONDS * 1000);
        
        // This means we're starting out connected, so make sure to increment
        // the channels and such. This will happen for incoming sockets
        // where this class is added dynamically after the initial connection.
        if (connected) {
            this.connectedChannels.incrementAndGet();
            this.lastConnected = System.currentTimeMillis();
        }
    }


    /**
     * Calls {@link ChannelHandlerContext#fireChannelActive()} to forward
     * to the next {@link ChannelStateHandler} in the {@link ChannelPipeline}.
     *
     * Sub-classes may override this method to change behavior.
     */
    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        try {
            this.connectedChannels.incrementAndGet();
        } finally {
            // The message is then just passed to the next handler
            super.channelActive(ctx);
        }
    }
    
    /**
     * Calls {@link ChannelHandlerContext#fireChannelInactive()} to forward
     * to the next {@link ChannelStateHandler} in the {@link ChannelPipeline}.
     *
     * Sub-classes may override this method to change behavior.
     */
    @Override
    public void channelInactive(ChannelHandlerContext ctx) throws Exception {
        ctx.fireChannelInactive();
        try {
            this.connectedChannels.decrementAndGet();
            if (this.connectedChannels.get() == 0) {
                this.lastConnected = System.currentTimeMillis();
            }
        } finally {
            // The message is then just passed to the next handler
            super.channelInactive(ctx);
        }
    }
    
    public boolean isConnected() {
        return connectedChannels.get() > 0;
    }

    public int getNumSockets() {
        return connectedChannels.get();
    }

    public long getLastConnected() {
        return this.lastConnected;
    }

    @Override
    public long getCumulativeReadBytes() {
        return trafficCounter.cumulativeReadBytes();
    }

    @Override
    public long getCumulativeWrittenBytes() {
        return trafficCounter.cumulativeWrittenBytes();
    }

    @Override
    public long getCurrentReadBytes() {
        return trafficCounter.currentReadBytes();
    }

    @Override
    public long getCurrentWrittenBytes() {
        return trafficCounter.currentWrittenBytes();
    }
}
