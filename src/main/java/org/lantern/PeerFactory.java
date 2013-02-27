package org.lantern;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;

import org.lantern.event.Events;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;
import org.lantern.state.Peer;
import org.lantern.state.Peer.Type;
import org.lantern.state.Peers;
import org.lantern.state.SyncPath;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class PeerFactory {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final ModelUtils modelUtils;
    private final Peers peers;

    /**
     * We create an executor here because we need to thread our geo-ip lookups.
     */
    private final ExecutorService exec = Executors.newCachedThreadPool(
        new ThreadFactory() {

        private volatile int count = 0;
        @Override
        public Thread newThread(final Runnable runner) {
            final Thread t = new Thread(runner, "Peer-Factory-Thread-"+count);
            t.setDaemon(true);
            count++;
            return t;
        }
    });

    @Inject
    public PeerFactory(final ModelUtils modelUtils, final Model model) {
        this.modelUtils = modelUtils;
        this.peers = model.getConnectivity().getPeerCollector();
    }

    public void addPeer(final String userId, final String ip, final int port,
        final Type type) {
        exec.submit(new Runnable() {

            @Override
            public void run() {
                final Peer peer = newGiveModePeer(userId, ip, port, type);
                peers.addPeer(peer);
                Events.sync(SyncPath.PEERS, peers.getPeers());
            }

        });
    }

    private Peer newGiveModePeer(final String userId, final String ip, final int port,
        final Type type) {
        final GeoData geo = modelUtils.getGeoData(ip);

        return new Peer(userId, geo.getCountrycode(), true, geo.getLatitude(),
            geo.getLongitude(), type, ip, Mode.give);
    }

    /*
    public Peer newPeer(final String userId, final Type type) {
        final GeoData geo = modelUtils.getGeoData(ip);
        return new Peer(userId, geo.getCountrycode(), false, geo.getLatitude(),
            geo.getLongitude(), type);
    }
    */
}
