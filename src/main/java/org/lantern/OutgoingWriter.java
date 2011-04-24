package org.lantern;

import java.io.IOException;

import org.jboss.netty.channel.MessageEvent;

public interface OutgoingWriter {

    void write(MessageEvent me) throws IOException;
}
