package org.lantern.event;

import org.jboss.netty.channel.Channel;

public class IncomingSocketEvent {

    private final Channel channel;

    public IncomingSocketEvent(final Channel channel) {
        this.channel = channel;
    }

    public Channel getChannel() {
        return channel;
    }

}
