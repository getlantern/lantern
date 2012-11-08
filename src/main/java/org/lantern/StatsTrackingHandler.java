package org.lantern;

import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelHandler;
import org.jboss.netty.channel.WriteCompletionEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public abstract class StatsTrackingHandler extends SimpleChannelHandler {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    public StatsTrackingHandler() {}
    
    @Override
    public void writeComplete(final ChannelHandlerContext ctx, 
        final WriteCompletionEvent e) {
        addUpBytes(e.getWrittenAmount(), ctx.getChannel());
    }
    
    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent e) throws Exception {
        final Object msg = e.getMessage();
        if (msg instanceof ChannelBuffer) {
            final ChannelBuffer cb = (ChannelBuffer) msg;
            addDownBytes(cb.readableBytes(), ctx.getChannel());
        }
        else {
            log.warn("StatsTrackingHandler messageRecieved was not " +
                "ChannelBuffer. Mislocated?");
        }
        super.messageReceived(ctx, e);
    }
    
    public abstract void addUpBytes(long bytes, Channel channel);
    public abstract void addDownBytes(long bytes, Channel channel);
    
    protected StatsTracker statsTracker() {
        return LanternHub.statsTracker();
    }
}