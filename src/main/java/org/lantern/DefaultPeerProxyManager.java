package org.lantern;

import java.io.IOException;
import java.net.Socket;
import java.net.URI;
import java.util.Comparator;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.PriorityBlockingQueue;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicInteger;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.MessageEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class the keeps track of P2P connections to peers, dispatching them and
 * creating new ones as needed.
 */
public class DefaultPeerProxyManager implements PeerProxyManager {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Executor exec = Executors.newCachedThreadPool(
        new ThreadFactory() {
        
        private int threadNumber = 0;
        @Override
        public Thread newThread(final Runnable r) {
            final Thread t = 
                new Thread(r, "P2P-Socket-Creation-Thread-"+threadNumber++);
            t.setDaemon(true);
            return t;
        }
    });
    
    /**
     * Priority queue of sockets ordered by how long it took them to be 
     * established.
     * 
     * Package-access for easier testing.
     */
    final PriorityBlockingQueue<ConnectionTimeSocket> timedSockets = 
        new PriorityBlockingQueue<ConnectionTimeSocket>(40, 
            new Comparator<ConnectionTimeSocket>() {

            @Override
            public int compare(final ConnectionTimeSocket cts1, 
                final ConnectionTimeSocket cts2) {
                return cts1.elapsed.compareTo(cts2.elapsed);
            }
        });

    private final boolean anon;
    
    public DefaultPeerProxyManager(final boolean anon) {
        this.anon = anon;
        
    }

    @Override
    public HttpRequestProcessor processRequest(
        final Channel browserToProxyChannel, final ChannelHandlerContext ctx, 
        final MessageEvent me) throws IOException {
        
        // This removes the highest priority socket.
        final ConnectionTimeSocket cts = this.timedSockets.poll();
        if (cts == null) {
            log.info("No peer sockets available!!");
            return null;
        }
        // When we use a socket, we always replace it with a new one.
        onPeer(cts.peerUri);
        cts.requestProcessor.processRequest(browserToProxyChannel, ctx, me);
        return cts.requestProcessor;
    }

    @Override
    public void onPeer(final URI peerUri) {
        if (!LanternHub.settings().isGetMode()) {
            log.info("Ingoring peer when we're in give mode");
            return;
        }
        log.info("Received peer URI {}...attempting connection...", peerUri);
        // Unclear how this count will be used for now.
        final Map<URI, AtomicInteger> peerFailureCount = 
            new HashMap<URI, AtomicInteger>();
        exec.execute(new Runnable() {

            @Override
            public void run() {
                try {
                    // We open a number of sockets because in almost every
                    // scenario the browser makes many connections to the proxy
                    // to open a single page.
                    for (int i = 0; i < 4; i++) {
                        final ConnectionTimeSocket ts = 
                            new ConnectionTimeSocket(peerUri);

                        final Socket sock = LanternUtils.openOutgoingPeerSocket(
                            peerUri, LanternHub.xmppHandler().getP2PClient(), 
                            peerFailureCount);
                        log.info("Got socket and adding it for peer: {}", peerUri);
                        ts.onSocket(sock);
                        timedSockets.add(ts);
                    }
                    LanternHub.eventBus().post(
                        new ConnectivityStatusChangeEvent(
                            ConnectivityStatus.CONNECTED));
                } catch (final IOException e) {
                    log.info("Could not create peer socket");
                }                
            }
            
        });
    }

    /**
     * Class holding a socket and an HTTP request processor that also tracks
     * connection times.
     * 
     * Package-access for easier testing.
     */
    final class ConnectionTimeSocket {
        private final long startTime = System.currentTimeMillis();
        Long elapsed;
        
        /**
         * We only store the peer URI so we can create a new connection to the
         * peer when this one succeeds.
         */
        private final URI peerUri;
        private HttpRequestProcessor requestProcessor;
        
        public ConnectionTimeSocket(final URI peerUri) {
            this.peerUri = peerUri;
        }

        private void onSocket(final Socket sock) {
            this.elapsed = System.currentTimeMillis() - this.startTime;
            if (anon) {
                this.requestProcessor = 
                    new PeerHttpConnectRequestProcessor(sock);
            } else {
                this.requestProcessor = 
                    new PeerChannelHttpRequestProcessor(sock);
                    //new PeerHttpRequestProcessor(sock);
            }
        }
    }

    @Override
    public void closeAll() {
        for (final ConnectionTimeSocket sock : this.timedSockets) {
            sock.requestProcessor.close();
        }
    }
}
