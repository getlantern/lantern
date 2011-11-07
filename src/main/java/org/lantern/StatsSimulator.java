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
    
    private final String[] IPS = {
            "78.110.96.6",  // Syria
            
            "78.110.96.7",  // Syria
            "78.110.96.8",  // Syria
            "78.110.96.9",  // Syria
            "78.110.96.10",  // Syria
            "78.110.96.11",  // Syria
            "78.110.96.12",  // Syria
            "78.110.96.13",  // Syria
            "212.95.136.18",  // Iran
            "212.95.136.19",  // Iran
            "212.95.136.20",  // Iran
            "212.95.136.21",  // Iran
            "212.95.136.22",  // Iran
            
            "58.14.0.1",  // China
            "58.14.0.2",  // China
            "58.14.0.3",  // China
            "58.14.0.4",  // China
            "58.14.0.5",  // China
            "58.14.0.6",  // China
            "58.14.0.7",  // China
            "58.14.0.8",  // China
            "58.14.0.9",  // China
            
            "190.6.64.1",  // Cuba"
            "190.6.64.2",  // Cuba"
            "190.6.64.3",  // Cuba"
            "190.6.64.4",  // Cuba"
            "58.186.0.1",  // Vietnam
            "58.186.0.2",  // Vietnam
            "58.186.0.3",  // Vietnam
            "82.114.160.1",  // Yemen
            "82.114.160.2",  // Yemen
            "82.114.160.3",  // Yemen
            "196.200.96.1",  // Eritrea
            "196.200.96.2",  // Eritrea
            "213.55.64.1",  // Ethiopia
            "213.55.64.2",  // Ethiopia
            "213.55.64.3",  // Ethiopia
            "213.55.64.4",  // Ethiopia
            "213.55.64.5",  // Ethiopia
            "213.55.64.6",  // Ethiopia
            "203.81.64.1",  // Myanmar
            "203.81.64.2",  // Myanmar
            "203.81.64.3",  // Myanmar
            "77.69.128.1",  // Bahrain
            "77.69.128.2",  // Bahrain
            "62.3.0.1",  // Saudi Arabia
            "62.3.0.2",  // Saudi Arabia
            "62.3.0.3",  // Saudi Arabia
            "62.3.0.4",  // Saudi Arabia
            "62.3.0.5",  // Saudi Arabia
            "62.3.0.6",  // Saudi Arabia
            "62.3.0.7",  // Saudi Arabia
            "62.209.128.0",  // Uzbekistan
            "62.209.128.1",  // Uzbekistan
            "62.209.128.2",  // Uzbekistan
            "94.102.176.1",  // Turkmenistan
            "94.102.176.2",  // Turkmenistan
            "94.102.176.3",  // Turkmenistan
            "94.102.176.4",  // Turkmenistan
            "94.102.176.5",  // Turkmenistan
        };
    
    public StatsSimulator() {
        
    }
    
    public void start() {
        final Thread sim = new Thread(new Runnable() {
            
            @Override
            public void run() {
                while (true) {
                    addData();
                    final double rand = Math.random();
                    final long millis = (long) (rand * 8000);
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
        final double newCountries = Math.random();
        final int nc = (int) (newCountries * 3);
        for (int i = 0; i < nc; i++) {
            final String ip = randomIp();
            final long bytes = (long) (Math.random() * 10000);
            LanternHub.statsTracker().incrementProxiedRequests();
            LanternHub.statsTracker().addBytesProxied(bytes, 
                new ChannelAdapter(ip));
        }
    }
    
    private String randomIp() {
        final int index = (int) (Math.random() * (IPS.length - 1));
        return IPS[index];
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
