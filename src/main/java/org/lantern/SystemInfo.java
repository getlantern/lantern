package org.lantern;

import com.google.common.eventbus.Subscribe;

/**
 * Class that stores general system info.
 */
public class SystemInfo implements MutableSystemSettings {

    private ConnectivityStatus connectivity; 
    private UpdateEvent updateData = new UpdateEvent();
    
    private Internet internet = new Internet();
    private Platform platform = new Platform();
    private boolean startAtLogin = true;
    private boolean isSystemProxy = true;
    private int port = LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
    private String version = LanternConstants.VERSION;
    private boolean connectOnLaunch = true;
    
    private String email;
    
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
        // Ignored since these are read-only and may change between writes to
        // disk -- so we don't want data to from disk to override dynamic
        // runtime data.
    }
    public Platform getPlatform() {
        return this.platform;
    }
    public void setPlatform(final Platform platform) {
        // Ignored since these are read-only and may change between writes to
        // disk -- so we don't want data to from disk to override dynamic
        // runtime data.
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

    public void setEmail(String email) {
        this.email = email;
    }

    public String getEmail() {
        return email;
    }
}
