package org.lantern;

import java.io.IOException;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.MessageEvent;

public interface HttpRequestProcessor {

    boolean hasProxy();
    
    void processRequest(Channel browserToProxyChannel,
        ChannelHandlerContext ctx, MessageEvent me) throws IOException;

    void processChunk(ChannelHandlerContext ctx, MessageEvent me) 
        throws IOException;

    void close();

}
