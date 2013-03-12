package org.lantern.util;

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

    /*
    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent e) throws Exception {
        try {
            this.connectedChannels.incrementAndGet();
            this.lastConnected = System.currentTimeMillis();
        } finally {
            // The message is then just passed to the next handler
            super.messageReceived(ctx, e);
        }
    }
    
    @Override
    public void channelConnected(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) throws Exception {
        try {
            this.connectedChannels.incrementAndGet();
            this.lastConnected = System.currentTimeMillis();
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
        } finally {
            // The message is then just passed to the next handler
            super.channelClosed(ctx, e);
        }
    }
    */
    
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
