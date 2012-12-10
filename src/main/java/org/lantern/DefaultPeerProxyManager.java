package org.lantern;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URI;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.TreeMap;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.PriorityBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.group.ChannelGroup;
import org.lantern.event.ConnectivityStatusChangeEvent;
import org.lantern.event.Events;
import org.lantern.event.ResetEvent;
import org.lantern.state.Model;
import org.lantern.state.Peer;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.common.util.concurrent.ThreadFactoryBuilder;
import com.maxmind.geoip.LookupService;

/**
 * Class the keeps track of P2P connections to peers, dispatching them and
 * creating new ones as needed.
 */
public class DefaultPeerProxyManager implements PeerProxyManager {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final Executor exec = Executors.newCachedThreadPool(
        new ThreadFactoryBuilder().setDaemon(true).setNameFormat(
            "P2P-Socket-Creation-Thread-%d").build());
    
    /**
     * Priority queue of sockets ordered by how long it took them to be 
     * established.
     * 
     * Package-access for easier testing.
     */
    final PriorityBlockingQueue<PeerSocketWrapper> timedSockets = 
        new PriorityBlockingQueue<PeerSocketWrapper>(40, 
            new Comparator<PeerSocketWrapper>() {

            @Override
            public int compare(final PeerSocketWrapper cts1, 
                final PeerSocketWrapper cts2) {
                return cts1.getConnectionTime().compareTo(cts2.getConnectionTime());
            }
        });
    
    private final Map<String, Peer> peers = new TreeMap<String, Peer>();

    private final boolean anon;
    
    /**
     * Online peers we've exchanged certs with.
     */
    private final Collection<URI> certPeers = new HashSet<URI>();

    private final ChannelGroup channelGroup;

    private final XmppHandler xmppHandler;

    private final Stats stats;

    private final LanternSocketsUtil socketsUtil;

    private final Model model;

    private final LookupService lookupService;
    
    public DefaultPeerProxyManager(final boolean anon, 
        final ChannelGroup channelGroup, final XmppHandler xmppHandler,
        final Stats stats, final LanternSocketsUtil socketsUtil,
        final Model model, final LookupService lookupService) {
        this.anon = anon;
        this.channelGroup = channelGroup;
        this.xmppHandler = xmppHandler;
        this.stats = stats;
        this.socketsUtil = socketsUtil;
        this.model = model;
        this.lookupService = lookupService;
        Events.register(this);
    }

    @Override
    public HttpRequestProcessor processRequest(
        final Channel browserToProxyChannel, final ChannelHandlerContext ctx, 
        final MessageEvent me) throws IOException {
        log.debug("Processing request...sockets in queue {} on this {}", 
            this.timedSockets.size(), this);
        
        final PeerSocketWrapper cts;
        try {
            cts = selectSocket();
        } catch (final IOException e) {
            // This means there's no socket available.
            return null;
        }
        if (!cts.getRequestProcessor().processRequest(browserToProxyChannel, ctx, me)) {
            log.info("Peer could not process the request...");
            // We return null here because that's how the dispatcher knows of
            // failures on peers.
            
            // TODO: We could also move on to other peers in this case instead
            // of falling back to centralized nodes.
            return null;
        }
        
        // When we use sockets we replace them.
        final int socketsToFetch;
        if (this.timedSockets.size() > 20) {
            socketsToFetch = 0;
        } else if (this.timedSockets.size() > 10) {
            socketsToFetch = 1;
        } else if (this.timedSockets.size() > 4) {
            socketsToFetch = 2;
        } else {
            socketsToFetch = 3;
        }
        onPeer(cts.getPeerUri(), socketsToFetch);
        return cts.getRequestProcessor();
    }

    private PeerSocketWrapper selectSocket() throws IOException {
        pruneSockets();
        if (this.timedSockets.isEmpty()) {
            // Try to create some more sockets using peers we've learned about.
            for (final URI peer : certPeers) {
                onPeer(peer, 2);
            }
        }
        // This removes the highest priority socket.
        for (int i = 0; i < this.timedSockets.size(); i++) {
            final PeerSocketWrapper cts;
            try {
                cts = this.timedSockets.poll(20, TimeUnit.SECONDS);
            } catch (final InterruptedException e) {
                log.info("Interrupted?", e);
                return null;
            }
            if (cts == null) {
                log.info("No peer sockets available!! TRUSTED: "+!anon);
                return null;
            }
            final Socket s = cts.getSocket();
            if (s != null) {
                if (!s.isClosed()) {
                    log.info("Found connected socket!");
                    return cts;
                }
            }
        }
        
        log.info("Could not find connected socket");
        throw new IOException("No availabe connected sockets in "+
            this.timedSockets);
    }
    

    private void pruneSockets() {
        final Iterator<PeerSocketWrapper> iter = this.timedSockets.iterator();
        while (iter.hasNext()) {
            final PeerSocketWrapper cts = iter.next();
            final Socket sock = cts.getSocket();
            if (sock != null) {
                if (sock.isClosed()) {
                    iter.remove();
                    final Peer peer = this.getPeers().get(cts.getPeerUri());
                    if (peer == null) {
                        log.warn("Could not find matching peer data?");
                    } else {
                        peer.removeSocket(cts);
                    }
                }
            }
        }
    }

    @Override
    public void onPeer(final URI peerUri) {
        onPeer(peerUri, 6);
    }

    private void onPeer(final URI peerUri, final int sockets) {
        if (!model.getSettings().isGetMode()) {
            log.info("Ingoring peer when we're in give mode");
            return;
        }
        if (this.anon && !model.getSettings().isUseAnonymousPeers()) {
            log.info("Ignoring anonymous peer");
            return;
        }
        if (!this.anon && !model.getSettings().isUseTrustedPeers()) {
            log.info("Ignoring trusted peer");
            return;
        }
        log.info("Received peer URI {}...attempting {} connections...", 
            peerUri, sockets);
        
        certPeers.add(peerUri);
        // Unclear how this count will be used for now.
        final Map<URI, AtomicInteger> peerFailureCount = 
            new HashMap<URI, AtomicInteger>();
        exec.execute(new Runnable() {
            @Override
            public void run() {
                boolean gotConnected = false;
                try {
                    // We open a number of sockets because in almost every
                    // scenario the browser makes many connections to the proxy
                    // to open a single page.
                    for (int i = 0; i < sockets; i++) {
                        final long now = System.currentTimeMillis();


                        final Socket sock = LanternUtils.openOutgoingPeerSocket(
                            peerUri, xmppHandler.getP2PClient(), 
                            peerFailureCount);
                        log.info("Got socket and adding it for peer: {}", peerUri);
                        addSocket(peerUri, now, sock);

                        if (!gotConnected) {
                            Events.eventBus().post(
                                new ConnectivityStatusChangeEvent(
                                    ConnectivityStatus.CONNECTED));
                        }
                        gotConnected = true;
                    }
                } catch (final IOException e) {
                    log.info("Could not create peer socket", e);
                }                
            }
        });
    }

    private void addSocket(final URI peerUri, final long startTime, 
        final Socket sock) {
        final PeerSocketWrapper ts = 
            new PeerSocketWrapper(peerUri, startTime, sock, this.anon, 
                this.channelGroup, this.stats, this.socketsUtil);
        
        this.timedSockets.add(ts);
        final Peer peer;
        final String userId = XmppUtils.jidToUser(peerUri.toASCIIString());
        if (this.getPeers().containsKey(userId)) {
            peer = this.peers.get(userId);
        } else {
            final String cc = 
                lookupService.getCountry(sock.getInetAddress()).getCode();
            final InetSocketAddress isa = 
                (InetSocketAddress) ts.getSocket().getRemoteSocketAddress();
            final String ip = isa.getAddress().getHostAddress();
            final int port = isa.getPort();
            peer = new Peer(userId, ip, port, cc, false, false, false);
            this.peers.put(userId, peer);
        }
        peer.addSocket(ts);
    }

    /**
     * Class holding a socket and an HTTP request processor that also tracks
     * connection times.
     * 
     * Package-access for easier testing.
     */
    /*
    public final class ConnectionTimeSocket {
        private final Long connectionTime;
        
        private final URI peerUri;
        private final HttpRequestProcessor requestProcessor;
        private final Socket sock;

        private final long startTime;

        public ConnectionTimeSocket(final URI peerUri, final long startTime, 
            final Socket sock) {
            this.peerUri = peerUri;
            this.sock = sock;
            this.startTime = startTime;
            this.connectionTime = System.currentTimeMillis() - startTime;
            if (anon) {
                this.requestProcessor = 
                    new PeerHttpConnectRequestProcessor(sock, channelGroup);
            } else {
                this.requestProcessor = 
                    new PeerChannelHttpRequestProcessor(sock, channelGroup);
                    //new PeerHttpRequestProcessor(sock);
            }
        }

        public Socket getSocket() {
            return sock;
        }

        public Long getConnectionTime() {
            return connectionTime;
        }

        public long getStartTime() {
            return startTime;
        }

        public URI getPeerUri() {
            return peerUri;
        }
    }
    */

    @Override
    public void removePeer(final URI uri) {
        this.certPeers.remove(uri);
        this.peers.remove(uri);
    }
    
    @Override
    public void closeAll() {
        for (final PeerSocketWrapper sock : this.timedSockets) {
            sock.getRequestProcessor().close();
        }
    }

    @Override
    public Map<String, Peer> getPeers() {
        return peers;
    }
    
    @Override
    public String toString() {
        return getClass().getSimpleName()+"-"+hashCode()+" anon: "+anon;
    }
    
    @Subscribe
    public void onReset(final ResetEvent event) {
        this.peers.clear();
        this.certPeers.clear();
        closeAll();
        this.timedSockets.clear();
    }
}
