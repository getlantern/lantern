package org.lantern;

import com.google.common.eventbus.Subscribe;

/**
 * Class that stores general system info.
 */
public class SystemInfo implements MutableSystemSettings {

    private ConnectivityStatus connectivity; 
    private UpdateEvent updateData = new UpdateEvent();
    
    private String location = LanternHub.censored().countryCode();
    private Internet internet;// = LanternHub.internet();
    private Platform platform;// = LanternHub.platform();
    private boolean startAtLogin = true;
    private boolean isSystemProxy = true;
    private int port = LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
    private String version = LanternConstants.VERSION;
    private boolean connectOnLaunch = true;
    
    {
        LanternHub.eventBus().register(this);
    }
    
    public SystemInfo() {
        
    }
    
    public SystemInfo(final Internet internet, final Platform platform) {
        this.internet = internet;
        this.platform = platform;
    }

    public boolean isSystemProxy() {
        return this.isSystemProxy;
    }
    
    @Override
    public void setSystemProxy(final boolean isSystemProxy) {
        this.isSystemProxy = isSystemProxy;
    }
    
    public boolean isStartAtLogin() {
        return this.startAtLogin;
    }
    @Override
    public void setStartAtLogin(final boolean startAtLogin) {
        this.startAtLogin = startAtLogin;
    }
    
    public int getPort() {
        return this.port;
    }
    
    @Override
    public void setPort(final int port) {
        this.port = port;
    }
    
    public ConnectivityStatus getConnectivity() {
        return connectivity;
    }
    public String getLocation() {
        return location;
    }
    
    @Override
    public void setLocation(final String location) {
        this.location = location;
    }
    public String getVersion() {
        return this.version;
    }
    public void setVersion(final String version) {
        this.version = version;
    }
    public UpdateEvent getUpdateData() {
        return updateData;
    }
    public Internet getInternet() {
        return internet;
    }
    
    public void setInternet(final Internet internet) {
        this.internet = internet;
    }
    public Platform getPlatform() {
        return this.platform;
    }
    public void setPlatform(final Platform platform) {
        this.platform = platform;
    }
    @Override
    public void setConnectOnLaunch(final boolean connectOnLaunch) {
        this.connectOnLaunch = connectOnLaunch;
    }
    public boolean isConnectOnLaunch() {
        return this.connectOnLaunch;
    }
    
    
    @Subscribe
    public void onUpdate(final UpdateEvent ue) {
        this.updateData = ue;
    }
    
    @Subscribe
    public void onConnectivityStateChanged(
        final ConnectivityStatusChangeEvent csce) {
        this.connectivity = csce.getConnectivityStatus();
    }
}
