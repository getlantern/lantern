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
import io.netty.buffer.ByteBufInputStream;
import io.netty.buffer.Unpooled;
import io.netty.channel.Channel;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.channel.ChannelHandler.Sharable;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundByteHandlerAdapter;
import io.netty.channel.ChannelOption;
import io.netty.channel.socket.nio.NioSocketChannel;
import io.netty.channel.udt.nio.NioUdtProvider;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;

import org.apache.commons.io.IOUtils;
import org.lantern.LanternClientConstants;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Handler implementation for the UDT relay server.
 */
@Sharable
public class UdtRelayServerIncomingHandler 
    extends ChannelInboundByteHandlerAdapter {

    private final static Logger log = 
            LoggerFactory.getLogger(UdtRelayServerIncomingHandler.class);

    private final int localProxyPort;
    
    private volatile Channel outboundChannel;

    private volatile Socket sock;
    
    public UdtRelayServerIncomingHandler(final int localProxyPort) {
        this.localProxyPort = localProxyPort;
    }
    
    @Override
    public void inboundBufferUpdated(final ChannelHandlerContext ctx,
            final ByteBuf in) throws IOException {
        // Just write incoming bytes to the outgoing connection to the 
        // destination server.
        log.debug("Inbound buffer with bytes: {}", in.readableBytes());
        //final ByteBuf out = outboundChannel.outboundByteBuffer();
        //out.writeBytes(in);
        if (this.sock.isConnected()) {
            final OutputStream os = sock.getOutputStream();
            ByteBufInputStream is = null;
            try  {
                is = new ByteBufInputStream(in);
                final byte[] incoming = new byte[is.available()];
                
                final int read = is.read(incoming);
                if (read != incoming.length) {
                    log.warn("Didn't read all the available bytes?!?");
                }
                os.write(incoming);
                os.flush();
                ctx.channel().read();
            } finally {
                IOUtils.closeQuietly(is);
            }

        } else {
            log.error("Socket not connected?");
            log.debug("Failed to flush data?");
            IOUtils.closeQuietly(sock);
            ctx.channel().close();
        }
    }
    
    private void netty4InboundBufferUpdated(final ChannelHandlerContext ctx,
            final ByteBuf in) {
        if (outboundChannel.isActive()) {
            outboundChannel.flush().addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(final ChannelFuture cf) 
                    throws Exception {
                    if (cf.isSuccess()) {
                        log.debug("Flushed data on outbound connection!!");
                        // Flushed out data - start to read the next chunk
                        ctx.channel().read();
                    } else {
                        log.debug("Failed to flush data?");
                        cf.channel().close();
                    }
                }
            });
        } else {
            log.warn("Outbound handler not active!");
        }
    }

    @Override
    public void exceptionCaught(final ChannelHandlerContext ctx,
            final Throwable cause) {
        log.debug("Close the connection when an exception is raised", cause);
        ctx.close();
    }

    @Override
    public void channelActive(final ChannelHandlerContext ctx) throws Exception {
        log.info("Relay channel active " + 
                NioUdtProvider.socketUDT(ctx.channel()).toStringOptions());
        final Channel inboundChannel = ctx.channel();
        
        socketRelay(inboundChannel);
        
        //netty4Relay(inboundChannel);
    }

    private static final int LARGE_BUFFER_SIZE = 1024 * 16;
    
    private void socketRelay(final Channel inboundChannel) throws IOException {
        this.sock = new Socket();
        try {
            sock.connect(new InetSocketAddress(
                LanternClientConstants.LOCALHOST, localProxyPort), 30*1000);
            inboundChannel.read();
        } catch (final IOException e) {
            log.warn("Outbound channel connection failed!");
            // Close the connection if the connection attempt has 
            // failed.
            inboundChannel.close();
        }
        
        readFromSocketThread(inboundChannel);
    }
    
    private void readFromSocketThread(final Channel inboundChannel) throws IOException {
        final InputStream is = this.sock.getInputStream();
        
        final Runnable runner = new Runnable() {
            public void run() {
                try {
                    copyLarge(is, inboundChannel, LARGE_BUFFER_SIZE);
                } catch (final IOException e) {
                    // This will happen if the other side just closes the
                    // socket, for example.
                    log.debug("Error copying socket data on", e);
                } catch (final Throwable t) {
                    log.warn("Error copying socket data on", t);
                } finally {
                    // Flush to be sure we've written everything.
                    inboundChannel.flush().addListener(new ChannelFutureListener() {
                        @Override
                        public void operationComplete(final ChannelFuture cf) 
                            throws Exception {
                            log.info("Closing inbound channel on flush");
                            inboundChannel.close();
                        }
                    });
                    IOUtils.closeQuietly(is);
                    
                    // This happens on JVM shutdown, for example.
                    log.info("Closing socket...already closed streams...");
                    IOUtils.closeQuietly(sock);
                }
            }
        };
        final Thread thread = new Thread(runner,
                "RelayingSocketHandler-Thread-"
                        + runner.hashCode());
        thread.setDaemon(true);
        thread.start();
    }
    
    private void copyLarge(final InputStream input, final Channel inboundChannel,
            final int bufferSize) throws IOException {
        final byte[] buffer = new byte[bufferSize];
        int n = 0;
        while (-1 != (n = input.read(buffer))) {
            //log.debug("Copying buf to inbound: {}\n"+new String(buffer), inboundChannel.hashCode());
            inboundChannel.write(Unpooled.wrappedBuffer(buffer, 0, n));
            try {
                inboundChannel.flush().sync();
            } catch (InterruptedException e) {
                log.error("Error flushing", e);
                throw new RuntimeException("Error flushing", e);
            }
        }
        log.debug("Copied bytes...");
    }
    
    private void netty4ProxyConnect(final Channel inboundChannel) {

        // Start the connection attempt.
        final Bootstrap clientBootstrapFromRelayToBackendServer = 
             new Bootstrap();
        clientBootstrapFromRelayToBackendServer.group(inboundChannel.eventLoop())
            .channel(NioSocketChannel.class)
            .handler(new UdtRelayServerBackendHandler(inboundChannel))
            .option(ChannelOption.AUTO_READ, false);
        
        final ChannelFuture cf = 
            clientBootstrapFromRelayToBackendServer.connect(
                LanternClientConstants.LOCALHOST, localProxyPort);
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
                    inboundChannel.close();
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
