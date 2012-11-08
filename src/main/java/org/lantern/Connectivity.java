package org.lantern;

import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.Settings.RuntimeSetting;

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
    
    @JsonView({RuntimeSetting.class})
    public String getPublicIp() {
        return this.ip;
    }

    public void setPublicIp(final String ip) {
        // This is set from settings.
        this.ip = ip;
    }
    
    @JsonView(RuntimeSetting.class)
    public GoogleTalkState getGTalk() {
        return googleTalkState;
    }
    
    @Subscribe
    public void onAuthenticationStateChanged(
        final GoogleTalkStateEvent ase) {
        this.googleTalkState = ase.getState();
        LanternHub.asyncEventBus().post(new SyncEvent(SyncChannel.connectivity));
    }
    
    @JsonView(RuntimeSetting.class)
    public ConnectivityStatus getConnectivity() {
        return connectivityStatus;
    }
    
    @Subscribe
    public void onConnectivityStateChanged(
        final ConnectivityStatusChangeEvent csce) {
        this.connectivityStatus = csce.getConnectivityStatus();
        LanternHub.asyncEventBus().post(new SyncEvent(SyncChannel.connectivity));
    }

}
