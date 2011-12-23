package org.lantern;


/**
 * Class that stores general system info.
 */
public class SystemInfo implements LanternUpdateListener, ConnectivityListener {

    private ConnectivityStatus connectivity; 
    private UpdateData updateData = new UpdateData();
    
    private String location = LanternHub.censored().countryCode();
    private Internet internet = LanternHub.internet();
    private Platform platform = LanternHub.platform();
    private boolean startAtLogin = true;
    private boolean isSystemProxy = true;
    private int port = LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
    private String version = LanternConstants.VERSION;
    private boolean connectOnLaunch = true;
    
    public boolean isSystemProxy() {
        return this.isSystemProxy;
    }
    
    public void setSystemProxy(final boolean isSystemProxy) {
        this.isSystemProxy = isSystemProxy;
    }
    
    
    public boolean isStartAtLogin() {
        return this.startAtLogin;
    }
    public void setStartAtLogin(final boolean startAtLogin) {
        this.startAtLogin = startAtLogin;
    }
    
    public int getPort() {
        return this.port;
    }
    
    public void setPort(final int port) {
        this.port = port;
    }
    
    public ConnectivityStatus getConnectivity() {
        return connectivity;
    }
    public String getLocation() {
        return location;
    }
    
    public void setLocation(final String location) {
        this.location = location;
    }
    public String getVersion() {
        return this.version;
    }
    public void setVersion(final String version) {
        this.version = version;
    }
    public UpdateData getUpdateData() {
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
    public void setConnectOnLaunch(final boolean connectOnLaunch) {
        this.connectOnLaunch = connectOnLaunch;
    }
    public boolean isConnectOnLaunch() {
        return this.connectOnLaunch;
    }
    @Override
    public void onUpdate(final UpdateData updateData) {
        this.updateData = updateData;
    }
    @Override
    public void onConnectivityStateChanged(final ConnectivityStatus ct) {
        this.connectivity = ct;
    }
}
