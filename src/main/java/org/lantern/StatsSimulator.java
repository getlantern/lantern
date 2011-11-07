package org.lantern;

import java.net.InetSocketAddress;
import java.net.SocketAddress;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelConfig;
import org.jboss.netty.channel.ChannelFactory;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelPipeline;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


public class StatsSimulator {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    public StatsSimulator() {
        
    }
    
    public void start() {
        final Thread sim = new Thread(new Runnable() {
            
            @Override
            public void run() {
                while (true) {
                    addData();
                    final double rand = Math.random();
                    final long millis = (long) (rand * 2000);
                    try {
                        Thread.sleep(millis);
                    } catch (final InterruptedException e) {
                        log.error("Sleep interrupted?", e);
                    }
                }
            }
        }, "Stats-Simulator-Thread");
        sim.setDaemon(true);
        sim.start();
    }

    protected void addData() {
        
        // Some dummy data for now.
        LanternHub.statsTracker().incrementProxiedRequests();
        LanternHub.statsTracker().incrementProxiedRequests(); 
        
        LanternHub.statsTracker().addBytesProxied(23210, 
            new ChannelAdapter("212.95.136.18")); // Iran
        LanternHub.statsTracker().addBytesProxied(478291, 
            new ChannelAdapter("78.110.96.7")); // Syria
    }
    

    private static class ChannelAdapter implements Channel {

        private final InetSocketAddress remoteAddress;

        private ChannelAdapter(final String address) {
            this.remoteAddress = new InetSocketAddress(address, 2781);
        }
        
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
            // TODO Auto-generated method stub
            return null;
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
            return remoteAddress;
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
        
    }
}
