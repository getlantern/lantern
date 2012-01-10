package org.lantern;

import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.WriteCompletionEvent;

class StatsTrackingUpstreamHandler extends SimpleChannelUpstreamHandler {
    
    private final boolean proxiedForOthers;
    
    public StatsTrackingUpstreamHandler() {
        this(false);
    }
    
    public StatsTrackingUpstreamHandler(boolean proxiedForOthers) {
        this.proxiedForOthers = proxiedForOthers;
    }
    
    @Override 
    public void writeComplete(ChannelHandlerContext ctx, WriteCompletionEvent e) {
        long bytes = e.getWrittenAmount();
        if (proxiedForOthers) {
            LanternHub.statsTracker().addUpBytesForOthers(bytes, ctx.getChannel());
        }
        else {
            LanternHub.statsTracker().addUpBytesViaOthers(bytes, ctx.getChannel());
        }
    }
}