package org.lantern;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelFutureListener;
import org.jboss.netty.channel.MessageEvent;

public class ChannelChunkWriter implements OutgoingWriter {

    private final ChannelFuture cf;

    public ChannelChunkWriter(ChannelFuture cf) {
        this.cf = cf;
    }

    public void write(final MessageEvent me) {
        
        final Channel ch = cf.getChannel();
        if (ch.isConnected()) {
            ch.write(me.getMessage());
        } else {
            cf.addListener(new ChannelFutureListener() {
                public void operationComplete(final ChannelFuture cf) 
                    throws Exception {
                    if (cf.isSuccess()) {
                        cf.getChannel().write(me.getMessage());
                    }
                }
            });
        }
    }

}
