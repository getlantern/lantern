package org.lantern;

import org.jboss.netty.channel.AbstractChannelSink;
import org.jboss.netty.channel.ChannelEvent;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelState;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.MessageEvent;

/** 
 */
class PeerSink extends AbstractChannelSink {
    
    @Override
    public void eventSunk(ChannelPipeline pipeline, ChannelEvent e) throws Exception {
        PeerSocketChannel channel = (PeerSocketChannel) e.getChannel();
        ChannelFuture future = e.getFuture();
        if (e instanceof ChannelStateEvent) {
            ChannelStateEvent stateEvent = (ChannelStateEvent) e;
            ChannelState state = stateEvent.getState();
            Object value = stateEvent.getValue(); 
            
            switch (state) {
            case OPEN: 
                if (Boolean.FALSE.equals(value)) {
                    PeerReadingWorker.close(channel, future);
                }
                break;
            case BOUND: 
                if (value == null) {
                    PeerReadingWorker.close(channel, future);
                }
                else {
                    throw new IllegalStateException("cannot re-bind peer socket channel");
                }
                break;
            case CONNECTED:
                if (value == null) {
                    PeerReadingWorker.close(channel, future);
                }
                else {
                    throw new IllegalStateException("cannot re-connect peer socket channel");
                }
                break;
            case INTEREST_OPS:
                PeerReadingWorker.setInterestOps(channel, future, ((Integer) value).intValue());
                break;
            }
        }
        else if (e instanceof MessageEvent) {
            PeerReadingWorker.write(channel, future, ((MessageEvent) e).getMessage());
        }
    }
}
