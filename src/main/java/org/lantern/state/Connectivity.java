package org.lantern.state;

import java.util.Collection;

import org.lantern.ConnectivityStatus;
import org.lantern.GoogleTalkState;
import org.lantern.LanternHub;
import org.lantern.PeerProxyManager;
import org.lantern.event.ConnectivityStatusChangeEvent;
import org.lantern.event.GoogleTalkStateEvent;
import org.lantern.event.SyncEvent;

import com.google.common.eventbus.Subscribe;

/**
 * Class representing data about Lantern's connectivity.
 */
public class Connectivity {
    
    private GoogleTalkState googleTalkState = GoogleTalkState.LOGGED_OUT;
    
    private ConnectivityStatus connectivityStatus = 
        ConnectivityStatus.DISCONNECTED; 

    private String ip = "";
    
    public Connectivity() {
        LanternHub.register(this);
    }
    
    public String getPublicIp() {
        return this.ip;
    }

    public void setPublicIp(final String ip) {
        // This is set from settings.
        this.ip = ip;
    }
    
    public GoogleTalkState getGTalk() {
        return googleTalkState;
    }
    
    public ConnectivityStatus getConnectivity() {
        return connectivityStatus;
    }
    
    public Collection<Peer> getPeers() {
        return peers(LanternHub.trustedPeerProxyManager());
    }
    
    public Collection<Peer> getAnonymousPeers() {
        return peers(LanternHub.anonymousPeerProxyManager());
    }
    
    private Collection<Peer> peers(final PeerProxyManager ppm) {
        return ppm.getPeers().values();
    }

    @Subscribe
    public void onAuthenticationStateChanged(final GoogleTalkStateEvent ase) {
        this.googleTalkState = ase.getState();
        LanternHub.asyncEventBus().post(new SyncEvent(SyncChannel.connectivity));
    }
    
    @Subscribe
    public void onConnectivityStateChanged(
        final ConnectivityStatusChangeEvent csce) {
        this.connectivityStatus = csce.getConnectivityStatus();
        LanternHub.asyncEventBus().post(new SyncEvent(SyncChannel.connectivity));
    }

}
