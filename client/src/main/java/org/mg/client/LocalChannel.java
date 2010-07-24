package org.mg.client;

import java.net.SocketAddress;
import java.util.Map;

import org.jboss.netty.buffer.ChannelBufferFactory;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelConfig;
import org.jboss.netty.channel.ChannelFactory;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.DefaultServerChannelConfig;

public class LocalChannel implements Channel {

    public ChannelFuture bind(SocketAddress arg0) {
        return null;
    }

    public ChannelFuture close() {
        return null;
    }

    public ChannelFuture connect(SocketAddress arg0) {
        return null;
    }

    public ChannelFuture disconnect() {
        return null;
    }

    public ChannelFuture getCloseFuture() {
        return null;
    }

    public ChannelConfig getConfig() {
        return new DefaultServerChannelConfig();
    }

    public ChannelFactory getFactory() {
        // TODO Auto-generated method stub
        return null;
    }

    public Integer getId() {
        // TODO Auto-generated method stub
        return null;
    }

    public int getInterestOps() {
        // TODO Auto-generated method stub
        return 0;
    }

    public SocketAddress getLocalAddress() {
        // TODO Auto-generated method stub
        return null;
    }

    public Channel getParent() {
        // TODO Auto-generated method stub
        return null;
    }

    public ChannelPipeline getPipeline() {
        // TODO Auto-generated method stub
        return null;
    }

    public SocketAddress getRemoteAddress() {
        // TODO Auto-generated method stub
        return null;
    }

    public boolean isBound() {
        // TODO Auto-generated method stub
        return false;
    }

    public boolean isConnected() {
        // TODO Auto-generated method stub
        return false;
    }

    public boolean isOpen() {
        // TODO Auto-generated method stub
        return false;
    }

    public boolean isReadable() {
        // TODO Auto-generated method stub
        return false;
    }

    public boolean isWritable() {
        // TODO Auto-generated method stub
        return false;
    }

    public ChannelFuture setInterestOps(int arg0) {
        // TODO Auto-generated method stub
        return null;
    }

    public ChannelFuture setReadable(boolean arg0) {
        // TODO Auto-generated method stub
        return null;
    }

    public ChannelFuture unbind() {
        // TODO Auto-generated method stub
        return null;
    }

    public ChannelFuture write(Object arg0) {
        // TODO Auto-generated method stub
        return null;
    }

    public ChannelFuture write(Object arg0, SocketAddress arg1) {
        // TODO Auto-generated method stub
        return null;
    }

    public int compareTo(Channel o) {
        // TODO Auto-generated method stub
        return 0;
    }

}
