package org.lantern;

import java.util.Set;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.ConcurrentSkipListSet;

import org.lastbamboo.common.p2p.P2PConnectionEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;


public class PeerCounter extends TimeSeries1D {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private final Set<String> peers; // this is always the current connected set of peers.
    private final Set<String> lifetimePeers; // this tracks unique peers seen in total
    private long lastBucket = -1;

    public PeerCounter() {
        this(DEFAULT_BUCKET_SIZE, NO_AGE_LIMIT);
    }
    
    public PeerCounter(long bucketSizeMillis) {
        this(bucketSizeMillis, NO_AGE_LIMIT);
    }
    
    public PeerCounter(long bucketSizeMillis, long ageLimit) {
        super(bucketSizeMillis, ageLimit);
        LanternHub.register(this);
        peers = new ConcurrentSkipListSet<String>();
        lifetimePeers = new ConcurrentSkipListSet<String>();
        
        // measure the current number of peers at regular intervals...
        final Timer timer = LanternHub.timer();
        timer.scheduleAtFixedRate(new TimerTask() {
            @Override
            public void run() {
                measurePeers();
            }
        }, 0, bucketSizeMillis);
    }
    
    @Override
    public void reset() {
        super.reset();
        peers.clear();
        lifetimePeers.clear();
    }
    
    protected void measurePeers() {
        long now = System.currentTimeMillis();
        long bucket = bucketForTimestamp(now);

        if (lastBucket != -1) {
            if (bucket == lastBucket) {
                log.warn("Peer counter updated faster than normal...");
                return;
            }
            if (bucket - lastBucket < 0) {
                log.warn("...sdrawkcab gninnur si emiT");
                return;
            }
            if (bucket - lastBucket > 1) {
                log.warn("Peer counter thread is running more than a bucket slow...");
            }
        }
        addData(now, peers.size());
        resetLifetimeTotal(lifetimePeers.size());
        lastBucket = bucket;
    }
    
    
    @Subscribe
    protected void onP2PConnectionEvent(final P2PConnectionEvent event) {
        // could obscure with hash, but not stored now.
        final String peerId = event.getJid(); 
        
        if (event.isConnected()) {
            peers.add(peerId);
            lifetimePeers.add(peerId);
        }
        else {
            peers.remove(peerId);
        }
    }
    
}