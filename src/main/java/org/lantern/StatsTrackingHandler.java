package org.lantern;

import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelHandler;
import org.jboss.netty.channel.WriteCompletionEvent;
import org.lantern.event.Events;
import org.lantern.event.IncomingSocketEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public abstract class StatsTrackingHandler extends SimpleChannelHandler 
    implements ByteTracker {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    public StatsTrackingHandler() {}
    
    @Override
    public void writeComplete(final ChannelHandlerContext ctx, 
        final WriteCompletionEvent e) {
        addUpBytes(e.getWrittenAmount());
    }
    
    @Override
    public void messageReceived(final ChannelHandlerContext ctx, 
        final MessageEvent e) throws Exception {
        final Object msg = e.getMessage();
        if (msg instanceof ChannelBuffer) {
            final ChannelBuffer cb = (ChannelBuffer) msg;
            addDownBytes(cb.readableBytes());
        }
        else {
            log.warn("StatsTrackingHandler messageRecieved was not " +
                "ChannelBuffer. Mislocated?");
        }
        super.messageReceived(ctx, e);
    }
    
    @Override
    public void channelOpen(final ChannelHandlerContext ctx, 
        final ChannelStateEvent cse) throws Exception {
        Events.asyncEventBus().post(
            new IncomingSocketEvent(ctx.getChannel(), cse, true));
    }
    
    @Override
    public void channelClosed(final ChannelHandlerContext ctx, 
        final ChannelStateEvent cse) {
        Events.asyncEventBus().post(
            new IncomingSocketEvent(ctx.getChannel(), cse, false));
    }
}