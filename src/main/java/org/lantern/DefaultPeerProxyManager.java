package org.lantern;

import java.io.IOException;
import java.net.InetAddress;
import java.net.Socket;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.TreeMap;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.PriorityBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.commons.lang3.StringUtils;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.group.ChannelGroup;
import org.lantern.event.ConnectedPeersEvent;
import org.lantern.event.Events;
import org.lantern.event.IncomingSocketEvent;
import org.lantern.event.ProxyConnectionEvent;
import org.lantern.event.ResetEvent;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;
import org.lantern.state.Peer;
import org.lantern.state.Settings.Mode;
import org.lantern.state.SyncPath;
import org.lastbamboo.common.p2p.P2PConnectionEvent;
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
    
    private final Map<String, Peer> peers = 
        Collections.synchronizedMap(new TreeMap<String, Peer>());

    private final boolean anon;
    
    /**
     * Online peers we've exchanged certs with.
     */
    private final Map<URI, String> certPeers = new HashMap<URI, String>();

    private final ChannelGroup channelGroup;

    private final XmppHandler xmppHandler;

    private final Stats stats;

    private final LanternSocketsUtil socketsUtil;

    private final Model model;

    private final LookupService lookupService;

    private final CertTracker certTracker;

    private final ModelUtils modelUtils;
    
    public DefaultPeerProxyManager(final boolean anon, 
        final ChannelGroup channelGroup, final XmppHandler xmppHandler,
        final Stats stats, final LanternSocketsUtil socketsUtil,
        final Model model, final LookupService lookupService,
        final CertTracker certTracker, final ModelUtils modelUtils) {
        this.anon = anon;
        this.channelGroup = channelGroup;
        this.xmppHandler = xmppHandler;
        this.stats = stats;
        this.socketsUtil = socketsUtil;
        this.model = model;
        this.lookupService = lookupService;
        this.certTracker = certTracker;
        this.modelUtils = modelUtils;
        Events.register(this);
    }

    @Override
    public HttpRequestProcessor processRequest(
        final Channel browserToProxyChannel, final ChannelHandlerContext ctx, 
        final MessageEvent me) throws IOException {
        log.debug("Processing request...sockets in queue {} on this {}", 
            this.timedSockets.size(), this);
        
        final PeerSocketWrapper peerSocket;
        try {
            peerSocket = selectSocket();
        } catch (final IOException e) {
            // This means there's no socket available.
            return null;
        }
        if (!peerSocket.getRequestProcessor().processRequest(browserToProxyChannel, ctx, me)) {
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
        final String cert = 
            this.certTracker.getCertForJid(peerSocket.getPeerUri().toASCIIString());
        onPeer(peerSocket.getPeerUri(), cert, socketsToFetch);
        return peerSocket.getRequestProcessor();
    }

    private PeerSocketWrapper selectSocket() throws IOException {
        pruneSockets();
        if (this.timedSockets.isEmpty()) {
            // Try to create some more sockets using peers we've learned about.
            for (final Map.Entry<URI,String> peer : certPeers.entrySet()) {
                onPeer(peer.getKey(), peer.getValue(), 2);
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
                    final Peer peer = 
                        this.peers.get(cts.getPeerUri().toASCIIString());
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
    public void onPeer(final URI peerUri, final String base64Cert) {
        onPeer(peerUri, base64Cert, 6);
    }

    private void onPeer(final URI peerUri, final String base64Cert, 
        final int sockets) {
        if (model.getSettings().getMode() == Mode.give) {
            log.debug("Ingoring peer when we're in give mode");
            return;
        }
        if (this.anon && !model.getSettings().isUseAnonymousPeers()) {
            log.debug("Ignoring anonymous peer");
            return;
        }
        if (!this.anon && !model.getSettings().isUseTrustedPeers()) {
            log.debug("Ignoring trusted peer");
            return;
        }
        log.debug("Received peer URI {}...attempting {} connections...", 
            peerUri, sockets);
        
        certPeers.put(peerUri, base64Cert);
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
                        addConnectedPeer(peerUri, base64Cert, now, sock, true, false);

                        if (!gotConnected) {
                            Events.eventBus().post(
                                new ProxyConnectionEvent(
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

    private void addConnectedPeer(final URI peerUri, final String base64Cert, 
        final long startTime, final Socket sock, final boolean addToSocketsInUse, 
        final boolean incoming) {
        final PeerSocketWrapper ts = 
            new PeerSocketWrapper(peerUri, startTime, sock, this.anon, 
                this.channelGroup, this.stats, this.socketsUtil, incoming);
        
        if (addToSocketsInUse) {
            this.timedSockets.add(ts);
        }
        final Peer peer;
        final String userId = XmppUtils.jidToUser(peerUri.toASCIIString());
        if (this.peers.containsKey(userId)) {
            peer = this.peers.get(userId);
        } else {
            final InetAddress ia = sock.getInetAddress();
            final GeoData geo = LanternUtils.getGeoData(ia.getHostAddress());
            peer = new Peer(userId, base64Cert, geo.getCountrycode(), false, 
                false, false, geo.getLatitude(), geo.getLongitude());
            this.peers.put(userId, peer);
        }
        peer.addSocket(ts);
        
        syncPeers();
    }

    @Override
    public void removePeer(final URI uri) {
        this.certPeers.remove(uri.toASCIIString());
        this.peers.remove(uri);
        syncPeers();
    }
    
    @Override
    public void closeAll() {
        for (final PeerSocketWrapper sock : this.timedSockets) {
            sock.getRequestProcessor().close();
        }
    }

    @Override
    public Collection<Peer> getPeers() {
        synchronized (peers) {
            return peers.values();
        }
    }
    
    @Subscribe
    public void onReset(final ResetEvent event) {
        this.peers.clear();
        this.certPeers.clear();
        closeAll();
        this.timedSockets.clear();
    }
    
    
    @Override
    public String toString() {
        return getClass().getSimpleName()+"-"+hashCode()+" anon: "+anon;
    }
    
    @Subscribe
    public void onIncomingSocket(final IncomingSocketEvent event) {
        final Channel ch = event.getChannel();
        if (event.isOpen()) {
            
        } else {
            
        }
    }
    
    /**
     * Track P2P connection events. Note this only tracks peers we're able
     * to directly connect to, not all peers we know about. Responding to these
     * events is necessary because it's the only way we can track incoming
     * sockets.
     * 
     * Note this still does not cover incoming connections directly to a 
     * port-mapped HTTP proxy. Those can only be identified by corresponding
     * certs, and those may or may not be availabe depending on if the IP was
     * cached across sessions.
     * 
     * @param event The P2P connection event.
     */
    @Subscribe
    public void onP2PConnectionEvent(final P2PConnectionEvent event) {
        log.debug("Got p2p connection event: {}", event);
        final String fullJid = event.getJid();
        final URI peerUri;
        try {
            peerUri = new URI(fullJid);
        } catch (final URISyntaxException e) {
            log.error("Could not read peer URI?", event.getJid());
            return;
        }
        
        final String cert = this.certTracker.getCertForJid(fullJid);
        if (StringUtils.isBlank(cert)) {
            log.warn("No cert for {} in {}", fullJid, this.certTracker);
        }
        
        final Socket sock = event.getSocket();
        // TODO: How the hell do we know we're getting notifications from 
        // anonymous peers? We don't here, so the "this.anon" argument below
        // is bogus.
        final PeerSocketWrapper ts = 
            new PeerSocketWrapper(peerUri, System.currentTimeMillis(), 
                sock, this.anon, this.channelGroup, this.stats, 
                this.socketsUtil, event.isIncoming());
        
        final Peer peer;
        final String userId = XmppUtils.jidToUser(peerUri.toASCIIString());
        if (this.peers.containsKey(userId)) {
            peer = this.peers.get(userId);
        } else {
            final GeoData geo = LanternUtils.getGeoData(
                sock.getInetAddress().getHostAddress());
            peer = new Peer(userId, cert, geo.getCountrycode(), false, false, 
                false, geo.getLatitude(), geo.getLongitude());
            this.peers.put(userId, peer);
        }
        peer.addSocket(ts);
        
        syncPeers();
    }

    private void syncPeers() {
        log.debug("Syncing peers...");
        Events.eventBus().post(new ConnectedPeersEvent(this));
        synchronized (this.peers) {
            final Collection<Peer> peerList = this.peers.values();
            Events.sync(SyncPath.PEERS, peerList);
        }
    }
}
