package org.lantern;

import java.io.OutputStream;
import java.io.PushbackInputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketAddress;

import org.jboss.netty.channel.AbstractChannel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelSink;
import org.jboss.netty.channel.Channels;
import org.jboss.netty.channel.socket.DefaultSocketChannelConfig;
import org.jboss.netty.channel.socket.SocketChannel;
import org.jboss.netty.channel.socket.SocketChannelConfig;


/**
 * A Channel wrapping an already connected peer proxy socket.
 * this is largely cargo-culted from org.jboss.netty.channel.socket.oio.OioSocketChannel
 * and org.jboss.netty.channel.socket.oio.OioClientSocketChannel
 * which are irritatingly non-public, much like this class.
 */ 
class PeerSocketChannel extends AbstractChannel implements SocketChannel {
    final Socket socket;
    final Object interestOpsLock = new Object();
    private final SocketChannelConfig config;
    volatile Thread workerThread;
    private volatile InetSocketAddress localAddress;
    private volatile InetSocketAddress remoteAddress;
    volatile PushbackInputStream in;
    volatile OutputStream out;

    PeerSocketChannel(
        ChannelPipeline pipeline,
        ChannelSink sink, 
        Socket peerSocket) {
        super(null, null, pipeline, sink);
        this.socket = peerSocket;
        config = new DefaultSocketChannelConfig(socket);
    }

    public void simulateConnect() {
        // these are always already bound and connected, so 
        // just act like someone called connect and it worked.
        try {
            Channels.fireChannelOpen(this);
            this.in = new PushbackInputStream(socket.getInputStream());
            this.out = socket.getOutputStream();
        
            Channels.fireChannelBound(this, getLocalAddress());
            Channels.fireChannelConnected(this, getRemoteAddress());
        
            // start an oio worker for ourself...
            Runnable runner = new PeerReadingWorker(this);
            final Thread peerReadingThread = 
                new Thread(runner, "Peer-Data-Reading-Thread");
            peerReadingThread.setDaemon(true);
            peerReadingThread.start();
        }
        catch (Throwable t) {
            Channels.fireExceptionCaught(this, t);
        }
    }

    @Override
    public SocketChannelConfig getConfig() {
        return config;
    }
    
    @Override
    public InetSocketAddress getLocalAddress() {
        InetSocketAddress localAddress = this.localAddress;
        if (localAddress == null) {
            try {
                this.localAddress = localAddress =
                    (InetSocketAddress) socket.getLocalSocketAddress();
            } catch (Throwable t) {
                // Sometimes fails on a closed socket in Windows.
                return null;
            }
        }
        return localAddress;
    }
    
    @Override
    public InetSocketAddress getRemoteAddress() {
        InetSocketAddress remoteAddress = this.remoteAddress;
        if (remoteAddress == null) {
            try {
                this.remoteAddress = remoteAddress =
                    (InetSocketAddress) socket.getRemoteSocketAddress();
            } catch (Throwable t) {
                // Sometimes fails on a closed socket in Windows.
                return null;
            }
        }
        return remoteAddress;
    }

    @Override
    public boolean isBound() {
        return isOpen() && socket.isBound();
    }

    @Override
    public boolean isConnected() {
        return isOpen() && socket.isConnected();
    }

    @Override
    protected boolean setClosed() {
        return super.setClosed();
    }

    @Override
    protected void setInterestOpsNow(int interestOps) {
        super.setInterestOpsNow(interestOps);
    }

    @Override
    public ChannelFuture write(Object message, SocketAddress remoteAddress) {
        if (remoteAddress == null || remoteAddress.equals(getRemoteAddress())) {
            return super.write(message, null);
        } else {
            return getUnsupportedOperationFuture();
        }
    }

    PushbackInputStream getInputStream() {
      return in;
    }

    OutputStream getOutputStream() {
      return out;
    }
}