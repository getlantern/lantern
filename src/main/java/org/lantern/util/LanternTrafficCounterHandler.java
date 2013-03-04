package org.lantern.util;

import java.util.concurrent.atomic.AtomicInteger;

import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.handler.traffic.GlobalTrafficShapingHandler;
import org.jboss.netty.util.Timer;
import org.lantern.LanternClientConstants;

public class LanternTrafficCounterHandler extends GlobalTrafficShapingHandler {

    private final AtomicInteger connectedChannels = new AtomicInteger(0);

    private long lastConnected = 0L;

    public LanternTrafficCounterHandler(final Timer timer, 
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
    
    public boolean isConnected() {
        return connectedChannels.get() > 0;
    }

    public int getNumSockets() {
        return connectedChannels.get();
    }

    public long getLastConnected() {
        return this.lastConnected;
    }
}
