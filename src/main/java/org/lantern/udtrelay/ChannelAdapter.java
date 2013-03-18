package org.lantern.udtrelay;

import java.net.SocketAddress;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelConfig;
import org.jboss.netty.channel.ChannelFactory;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.DefaultChannelConfig;

public class ChannelAdapter implements Channel {

    private final ChannelConfig config = new DefaultChannelConfig();
    
    @Override
    public int compareTo(Channel o) {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public Integer getId() {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public ChannelFactory getFactory() {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public Channel getParent() {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public ChannelConfig getConfig() {
        return config;
    }

    @Override
    public ChannelPipeline getPipeline() {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public boolean isOpen() {
        // TODO Auto-generated method stub
        return false;
    }

    @Override
    public boolean isBound() {
        // TODO Auto-generated method stub
        return false;
    }

    @Override
    public boolean isConnected() {
        // TODO Auto-generated method stub
        return false;
    }

    @Override
    public SocketAddress getLocalAddress() {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public SocketAddress getRemoteAddress() {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public ChannelFuture write(Object message) {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public ChannelFuture write(Object message, SocketAddress remoteAddress) {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public ChannelFuture bind(SocketAddress localAddress) {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public ChannelFuture connect(SocketAddress remoteAddress) {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public ChannelFuture disconnect() {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public ChannelFuture unbind() {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public ChannelFuture close() {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public ChannelFuture getCloseFuture() {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public int getInterestOps() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public boolean isReadable() {
        // TODO Auto-generated method stub
        return false;
    }

    @Override
    public boolean isWritable() {
        // TODO Auto-generated method stub
        return false;
    }

    @Override
    public ChannelFuture setInterestOps(int interestOps) {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public ChannelFuture setReadable(boolean readable) {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public Object getAttachment() {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public void setAttachment(Object attachment) {
        // TODO Auto-generated method stub

    }

}
