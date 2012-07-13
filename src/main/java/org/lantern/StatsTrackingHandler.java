package org.lantern;

import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelHandler;
import org.jboss.netty.channel.WriteCompletionEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class StatsTrackingHandler extends SimpleChannelHandler {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Override
    public void writeComplete(ChannelHandlerContext ctx, WriteCompletionEvent e) {
        long bytes = e.getWrittenAmount();
        addUpBytes(e.getWrittenAmount(), ctx.getChannel());
    }
    
    @Override
    public void messageReceived(ChannelHandlerContext ctx, MessageEvent e) throws Exception {
        Object msg = e.getMessage();
        if (msg instanceof ChannelBuffer) {
            ChannelBuffer cb = (ChannelBuffer) msg;
            addDownBytes(cb.readableBytes(), ctx.getChannel());
        }
        else {
            log.warn("StatsTrackingHandler messageRecieved was not ChannelBuffer.  Mislocated?");
        }
        super.messageReceived(ctx, e);
    }
    
    public void addUpBytes(long bytes, Channel channel) {}
    public void addDownBytes(long bytes, Channel channel) {}
    
    protected StatsTracker statsTracker() {
        return LanternHub.statsTracker();
    }
}