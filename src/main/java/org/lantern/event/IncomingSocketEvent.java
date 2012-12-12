package org.lantern.event;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelStateEvent;

public class IncomingSocketEvent {

    private final Channel channel;
    private final boolean open;
    private final ChannelStateEvent cse;

    public IncomingSocketEvent(final Channel channel, 
        final ChannelStateEvent cse, final boolean open) {
        this.channel = channel;
        this.cse = cse;
        this.open = open;
    }

    public Channel getChannel() {
        return channel;
    }

    public boolean isOpen() {
        return open;
    }

    public ChannelStateEvent getCse() {
        return cse;
    }

}
