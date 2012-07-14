package org.lantern;

import java.net.InetSocketAddress;
import java.net.SocketAddress;
import java.util.ArrayList;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelConfig;
import org.jboss.netty.channel.ChannelFactory;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelPipeline;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


public class StatsSimulator {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final ArrayList<String> IPS = new ArrayList<String>();
    
    public StatsSimulator() {
        populateIps();
    }
    
    private void populateIps() {
        addIps("77.69.128.", 10); // Bahrain
        addIps("58.14.0.", 200); // China
        addIps("190.6.64.", 60); // Cuba
        //addIps("196.200.96.", 100); // Eritrea
        addIps("213.55.64.", 50); // Ethiopia
        addIps("46.36.195.", 100); // Indonesia
        addIps("212.95.136.", 100); // Iran
        addIps("49.1.0.", 120); // South Korea
        addIps("203.81.64.", 100); // Myanmar
        addIps("175.45.176.", 100); // North Korea
        
        addIps("46.36.195.", 80); // Oman
        addIps("46.36.195.", 80); // Qatar
        addIps("39.32.0.", 80); // Pakistan
        
        addIps("62.3.0.", 80); // Saudi Arabia
        addIps("31.201.1.", 60); // Sudan
        addIps("78.110.96.", 45); // Syria
        addIps("94.102.176.", 80); // Turkmenistan
        addIps("85.115.64.", 40); // United Arab Emirates
        addIps("62.209.128.", 60); // Uzbekistan
        addIps("58.186.0.", 70); // Vietnam
        addIps("82.114.160.", 100); // Yemen
    }

    private void addIps(final String base, final int num) {
        for (int i = 0; i < num; i++) {
            IPS.add(base+i);
        }
    }

    public void start() {
        final Thread sim = new Thread(new Runnable() {
            
            @Override
            public void run() {
                while (true) {
                    addData();
                    final double rand = Math.random();
                    final long millis = (long) (rand * 1200);
                    try {
                        Thread.sleep(800 + millis);
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
        final int index = (int) (Math.random() * (IPS.size() - 1));
        return IPS.get(index);
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

        @Override
        public Object getAttachment() {
            // TODO Auto-generated method stub
            return null;
        }

        @Override
        public void setAttachment(Object arg0) {
            // TODO Auto-generated method stub
            
        }
        
    }
}
