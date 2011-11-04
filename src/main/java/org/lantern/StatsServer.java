package org.lantern;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketAddress;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelConfig;
import org.jboss.netty.channel.ChannelFactory;
import org.jboss.netty.channel.ChannelFuture;
import org.jboss.netty.channel.ChannelPipeline;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.util.concurrent.ThreadFactoryBuilder;

/**
 * Class that serves JSON stats over REST.
 */
public class StatsServer {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final ExecutorService service = 
        Executors.newCachedThreadPool(
            new ThreadFactoryBuilder().setDaemon(true).build());
    
    public void serve() {
        service.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    final ServerSocket server = new ServerSocket();
                    server.bind(new InetSocketAddress("127.0.0.1", 7878));
                    while (true) {
                        final Socket sock = server.accept();
                        processSocket(sock);
                    }
                } catch (final IOException e) {
                    log.error("Could not run stats server?", e);
                }
            }
        });
        
        // Some dummy data for now.
        LanternHub.statsTracker().incrementProxiedRequests();
        LanternHub.statsTracker().incrementProxiedRequests(); 
        
        LanternHub.statsTracker().addBytesProxied(23210, 
            new ChannelAdapter("212.95.136.18")); // Iran
        LanternHub.statsTracker().addBytesProxied(478291, 
            new ChannelAdapter("78.110.96.7")); // Syria
    }

    private void processSocket(final Socket sock) {
        service.execute(new Runnable() {

            @Override
            public void run() {
                log.info("Got socket!!");
                try {
                    final InputStream is = sock.getInputStream();
                    final BufferedReader br = 
                        new BufferedReader(new InputStreamReader(is, "UTF-8"));
                    String cur = br.readLine();
                    if (StringUtils.isBlank(cur)) {
                        log.info("Closing blank request socket");
                        IOUtils.closeQuietly(sock);
                        return;
                    } 
                    
                    if (!cur.startsWith("GET /stats")) {
                        log.info("Ignoring request with line: "+cur);
                        IOUtils.closeQuietly(sock);
                        return;
                    }
                    while (StringUtils.isNotBlank(cur)) {
                        log.info(cur);
                        cur = br.readLine();
                    }
                    log.info("Read all headers...");
                    
                    final String body = LanternHub.statsTracker().toJson();
                    OutputStream os = sock.getOutputStream();
                    final String response = 
                        "HTTP/1.1 200 OK\r\n"+
                        "Content-Type: application/json\r\n"+
                        "Connection: close\r\n"+
                        "Content-Length: "+body.length()+"\r\n"+
                        "\r\n"+
                        body;
                    os.write(response.getBytes("UTF-8"));
                } catch (final IOException e) {
                    log.info("Exception serving stats!", e);
                } finally {
                    IOUtils.closeQuietly(sock);
                }
            }
            
        });
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
