package org.lantern.util;

import java.util.concurrent.atomic.AtomicInteger;

import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.handler.traffic.GlobalTrafficShapingHandler;
import org.jboss.netty.util.Timer;

public class LanternTrafficCounterHandler extends GlobalTrafficShapingHandler {

    private final AtomicInteger connectedChannels = new AtomicInteger(0);

    public LanternTrafficCounterHandler(final Timer timer) {
        super(timer, 1000);
    }

    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) throws Exception {
        this.connectedChannels.incrementAndGet();
    }
    
    @Override
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent e) throws Exception {
        this.connectedChannels.decrementAndGet();
    }
    
    public boolean isConnected() {
        return connectedChannels.get() > 0;
    }
}
