package org.lantern;

import java.io.IOException;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.MessageEvent;

/**
 * Processor for HTTP requests. Different implementations might go to peers or
 * other forms of proxies, or even reply directly through a cache.
 */
public interface HttpRequestProcessor {

    boolean processRequest(Channel browserToProxyChannel,
        ChannelHandlerContext ctx, MessageEvent me) throws IOException;

    boolean processChunk(ChannelHandlerContext ctx, MessageEvent me) 
        throws IOException;

    void close();

}
