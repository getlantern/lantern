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
        final ScheduledExecutorService executor) {
        super(executor, LanternClientConstants.SYNC_INTERVAL_SECONDS * 1000);
    }

    @Override
    public void incrementSockets() {
        // This is often necessary because this handler will be added
        // dynamically in connection events themselves, so otherwise it would
        // miss connections.
        this.connectedChannels.incrementAndGet();
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
