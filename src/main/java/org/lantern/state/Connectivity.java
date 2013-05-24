package org.lantern.state;

import java.util.Date;

import org.apache.commons.lang3.StringUtils;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.GoogleTalkState;
import org.lantern.LanternConstants;
import org.lantern.event.Events;
import org.lantern.event.GoogleTalkStateEvent;
import org.lantern.event.SyncEvent;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;
import org.lantern.state.Peer.Type;
import org.lantern.state.StaticSettings;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

/**
 * Class representing data about Lantern's connectivity.
 */
public class Connectivity {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private GoogleTalkState gtalk = GoogleTalkState.notConnected;

    private String ip = "";

    private boolean gtalkAuthorized = false;

    private boolean internet = false;

    private boolean invited = false;

    private String peerId = "";

    private boolean lanternController;

    private String connectingStatus;

    private Type type = LanternConstants.ON_APP_ENGINE ? Type.cloud : Type.pc;

    private long lastConnectedLong;

    private String pacUrl;

    public Connectivity() {
        Events.register(this);
    }

    @JsonView({Run.class})
    public GoogleTalkState getGTalk() {
        return gtalk;
    }

    @Subscribe
    public void onAuthenticationStateChanged(final GoogleTalkStateEvent ase) {
        this.gtalk = ase.getState();
        log.debug("Setting peer ID to: '{}'", ase.getJid());
        final String id = ase.getJid();
        if (StringUtils.isNotBlank(id)) {
            this.peerId = id;
        }
        Events.sync(SyncPath.CONNECTIVITY_GTALK, this.gtalk);
    }

    @JsonView({Run.class})
    public String getIp() {
        return ip;
    }

    public void setIp(String ip) {
        this.ip = ip;
    }

    @JsonView({Run.class})
    public String getGtalkOauthUrl() {
        return StaticSettings.getLocalEndpoint()+"/oauth/";
    }

    @JsonView({Run.class})
    public boolean isGtalkAuthorized() {
        return gtalkAuthorized;
    }

    public void setGtalkAuthorized(boolean gtalkAuthorized) {
        this.gtalkAuthorized = gtalkAuthorized;
    }

    @JsonView({Run.class})
    public boolean isInternet() {
        return internet;
    }

    public void setInternet(final boolean internet) {
        this.internet = internet;
    }

    @JsonView({Run.class, Persistent.class})
    public boolean isInvited() {
        return invited;
    }

    public void setInvited(boolean invited) {
        this.invited = invited;
    }

    public boolean getLanternController() {
        return lanternController;
    }

    public void setLanternController(boolean lanternController) {
        this.lanternController = lanternController;
    }

    @JsonView({Run.class})
    public String getPeerid() {
        return peerId;
    }

    @JsonView({Run.class})
    public String getPacUrl() {
        if(pacUrl == null || pacUrl.equals("")) {
            return StaticSettings.getLocalEndpoint()+"/proxy_on.pac";
        }
        return pacUrl;
    }

    public void setPacUrl(final String url) {
        this.pacUrl = url;
    }

    public String getConnectingStatus() {
        return connectingStatus;
    }

    public void setConnectingStatus(final String connectingStatus) {
        this.connectingStatus = connectingStatus;
    }

    public Type getType() {
        return type;
    }

    public void setType(Type type) {
        this.type = type;
    }

    public Date getLastConnected() {
        return new Date(lastConnectedLong);
    }

    public void setLastConnected(Date lastConnected) {
        this.lastConnectedLong = lastConnected.getTime();
    }

    @Subscribe
    protected void onPeerLastConnectedChangedEvent(final PeerLastConnectedChangedEvent event) {
        Peer peer = event.getPeer();
        if (peer.getLastConnectedLong() > lastConnectedLong) {
            lastConnectedLong = peer.getLastConnectedLong();
        }
    }
}
