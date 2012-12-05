package org.lantern;

import org.lantern.event.Events;
import org.lastbamboo.common.p2p.P2PConnectionEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

/**
 * This class caches peers we may be able to connect to in the future in case
 * all goes to hell.
 */
public class PeerTracker {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    {
        Events.register(this);
    }

    @Subscribe
    protected void onP2PConnectionEvent(final P2PConnectionEvent event) {
        if (event.isIncoming()) {
            log.debug("Ignoring incoming sockets since we don't know where " +
                "to connect to");
            return;
        }
        
        /*
        final Socket sock = event.getSocket();
        if (sock instanceof SSLSocket) {
            ((SSLSocket)sock).
            LanternHub.settings().addPeerProxy(event.getRemoteSocketAddress());
        }
        */
    }
}
