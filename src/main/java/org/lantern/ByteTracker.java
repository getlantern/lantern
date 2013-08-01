package org.lantern;

import org.jboss.netty.channel.Channel;


public interface ByteTracker {

    void addUpBytes(long bytes, Channel channel);
    void addDownBytes(long bytes, Channel channel);
}
