/*
 * Copyright 2012 The Netty Project
 *
 * The Netty Project licenses this file to you under the Apache License,
 * version 2.0 (the "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at:
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */
package org.lantern.udtrelay;

import io.netty.bootstrap.Bootstrap;
import io.netty.buffer.ByteBuf;
import io.netty.channel.Channel;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.channel.ChannelHandler.Sharable;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundByteHandlerAdapter;
import io.netty.channel.ChannelOption;
import io.netty.channel.socket.nio.NioSocketChannel;
import io.netty.channel.udt.nio.NioUdtProvider;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handler implementation for the echo server.
 */
@Sharable
public class UdtRelayServerIncomingHandler 
    extends ChannelInboundByteHandlerAdapter {

    private final static Logger log = 
            LoggerFactory.getLogger(UdtRelayServerIncomingHandler.class);

    private final String remoteHost;
    private final int remotePort;
    
    private volatile Channel outboundChannel;
    
    public UdtRelayServerIncomingHandler(final String remoteHost, 
        final int remotePort) {
        this.remoteHost = remoteHost;
        this.remotePort = remotePort;
    }
    
    @Override
    public void inboundBufferUpdated(final ChannelHandlerContext ctx,
            final ByteBuf in) {
        log.debug("Got inbound buffer updated!!!");
        final ByteBuf out = ctx.nextOutboundByteBuffer();
        out.discardReadBytes();
        out.writeBytes(in);
        ctx.flush();
    }

    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx,
            final Throwable cause) {
        log.debug("Close the connection when an exception is raised", cause);
        ctx.close();
    }

    @Override
    public void channelActive(final ChannelHandlerContext ctx) throws Exception {
        log.info("ECHO active " + 
                NioUdtProvider.socketUDT(ctx.channel()).toStringOptions());
        final Channel inboundChannel = ctx.channel();

        // Start the connection attempt.
        final Bootstrap clientBootstrapFromRelayToBackendServer = 
             new Bootstrap();
        clientBootstrapFromRelayToBackendServer.group(inboundChannel.eventLoop())
            .channel(NioSocketChannel.class)
            .handler(new UdtRelayServerBackendHandler(inboundChannel))
            .option(ChannelOption.AUTO_READ, false);
        
        final ChannelFuture cf = 
            clientBootstrapFromRelayToBackendServer.connect(remoteHost, remotePort);
        outboundChannel = cf.channel();
        
        cf.addListener(new ChannelFutureListener() {
            @Override
            public void operationComplete(ChannelFuture future) 
                throws Exception {
                if (future.isSuccess()) {
                    log.debug("Outbound channel connected!");
                    // Connection complete start to read first data
                    inboundChannel.read();
                    log.debug("Reading from inbound channel");
                } else {
                    log.warn("Outbound channel connection failed!");
                    // Close the connection if the connection attempt has 
                    // failed.
                    //inboundChannel.close();
                }
            }
        });
    }

    @Override
    public ByteBuf newInboundBuffer(final ChannelHandlerContext ctx)
            throws Exception {
        return ctx.alloc().directBuffer(
                ctx.channel().config().getOption(ChannelOption.SO_RCVBUF));
    }

}
