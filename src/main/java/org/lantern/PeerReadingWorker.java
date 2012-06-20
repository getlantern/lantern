package org.lantern;

import java.io.OutputStream;
import java.io.PushbackInputStream;
import java.net.SocketException;
import java.nio.channels.ClosedChannelException;
import java.util.regex.Pattern;

import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.Channels;


/** 
 * this is a worker that reads from the peer socket channel.
 * largely cargo culted from org.jboss.netty.channel.socket.oio.OioWorker
 * which is private and a bit more general.
 */
class PeerReadingWorker implements Runnable {
    
    private static final Pattern SOCKET_CLOSED_MESSAGE = Pattern.compile(
              "^.*(?:Socket.*closed).*$", Pattern.CASE_INSENSITIVE);
    
    PeerSocketChannel channel; 
    
    PeerReadingWorker(PeerSocketChannel peerChannel) {
        this.channel = peerChannel;
    }
    
    @Override
    public void run() {
        channel.workerThread = Thread.currentThread();
        final PushbackInputStream in = channel.getInputStream();

        while (channel.isOpen()) {
            synchronized (channel.interestOpsLock) {
                while (!channel.isReadable()) {
                    try {
                        // notify() is not called at all.
                        // close() and setInterestOps() calls Thread.interrupt()
                        channel.interestOpsLock.wait();
                    } catch (InterruptedException e) {
                        if (!channel.isOpen()) {
                            break;
                        }
                    }
                }
            }

            byte[] buf;
            int readBytes;
            try {
                int bytesToRead = in.available();
                if (bytesToRead > 0) {
                    buf = new byte[bytesToRead];
                    readBytes = in.read(buf);
                } else {
                    int b = in.read();
                    if (b < 0) {
                        break;
                    }
                    in.unread(b);
                    continue;
                }
            } catch (Throwable t) {
                if (!channel.socket.isClosed()) {
                    Channels.fireExceptionCaught(channel, t);
                }
                break;
            }

            Channels.fireMessageReceived(
                    channel,
                    channel.getConfig().getBufferFactory().getBuffer(buf, 0, readBytes));
        }

        // Setting the workerThread to null will prevent any channel
        // operations from interrupting this thread from now on.
        channel.workerThread = null;

        // Clean up.
        close(channel, Channels.succeededFuture(channel));
    }

    static void write(
            PeerSocketChannel channel, ChannelFuture future,
            Object message) {

        OutputStream out = channel.getOutputStream();
        if (out == null) {
            Exception e = new ClosedChannelException();
            future.setFailure(e);
            Channels.fireExceptionCaught(channel, e);
            return;
        }

        try {
            int length = 0;

            ChannelBuffer a = (ChannelBuffer) message;
            length = a.readableBytes();
            synchronized (out) {
                a.getBytes(a.readerIndex(), out, length);
            }

            Channels.fireWriteComplete(channel, length);
            future.setSuccess();
        
        } catch (Throwable t) {
            // Convert 'SocketException: Socket closed' to
            // ClosedChannelException.
            if (t instanceof SocketException &&
                    SOCKET_CLOSED_MESSAGE.matcher(
                            String.valueOf(t.getMessage())).matches()) {
                t = new ClosedChannelException();
            }
            future.setFailure(t);
            Channels.fireExceptionCaught(channel, t);
        }
    }

    static void setInterestOps(
            PeerSocketChannel channel, ChannelFuture future, int interestOps) {

        // Override OP_WRITE flag - a user cannot change this flag.
        interestOps &= ~Channel.OP_WRITE;
        interestOps |= channel.getInterestOps() & Channel.OP_WRITE;

        boolean changed = false;
        try {
            if (channel.getInterestOps() != interestOps) {
                if ((interestOps & Channel.OP_READ) != 0) {
                    channel.setInterestOpsNow(Channel.OP_READ);
                } else {
                    channel.setInterestOpsNow(Channel.OP_NONE);
                }
                changed = true;
            }

            future.setSuccess();
            if (changed) {
                synchronized (channel.interestOpsLock) {
                    channel.setInterestOpsNow(interestOps);

                    // Notify the worker so it stops or continues reading.
                    Thread currentThread = Thread.currentThread();
                    Thread workerThread = channel.workerThread;
                    if (workerThread != null && currentThread != workerThread) {
                        workerThread.interrupt();
                    }
                }

                Channels.fireChannelInterestChanged(channel);
            }
        } catch (Throwable t) {
            future.setFailure(t);
            Channels.fireExceptionCaught(channel, t);
        }
    }

    static void close(PeerSocketChannel channel, ChannelFuture future) {
        boolean connected = channel.isConnected();
        boolean bound = channel.isBound();
        try {
            channel.socket.close();
            if (channel.setClosed()) {
                future.setSuccess();
                if (connected) {
                    // Notify the worker so it stops reading.
                    Thread currentThread = Thread.currentThread();
                    Thread workerThread = channel.workerThread;
                    if (workerThread != null && currentThread != workerThread) {
                        workerThread.interrupt();
                    }
                    Channels.fireChannelDisconnected(channel);
                }
                if (bound) {
                    Channels.fireChannelUnbound(channel);
                }
                Channels.fireChannelClosed(channel);
            } else {
                future.setSuccess();
            }
        } catch (Throwable t) {
            future.setFailure(t);
            Channels.fireExceptionCaught(channel, t);
        }
    }
}
