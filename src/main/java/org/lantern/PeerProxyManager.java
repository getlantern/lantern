package org.lantern;

import java.io.IOException;
import java.net.URI;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.MessageEvent;

/**
 * Interface for classes that store established P2P sockets.
 */
public interface PeerProxyManager {

    void onPeer(URI peerUri);

    HttpRequestProcessor processRequest(Channel browserToProxyChannel,
       ChannelHandlerContext ctx, MessageEvent me) throws IOException;
    
    void closeAll();

    void removePeer(URI uri);

}
