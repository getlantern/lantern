package org.lantern;

/**
 * Class that stores general system info.
 */
public class SystemInfo implements LanternUpdateListener, ConnectivityListener {

    private ConnectivityStatus connectivity; 
    private UpdateData updateData = new UpdateData();
    
    public boolean isSystemProxy() {
        return LanternUtils.shouldProxy();
    }
    
    // TODO: Add setSystemProxy.
    
    public boolean isStartAtLogin() {
        return LanternUtils.getBooleanProperty(LanternConstants.START_AT_LOGIN, 
            true);
    }
    public void setStartAtLogin(final boolean startAtLogin) {
        LanternUtils.setBooleanProperty(LanternConstants.START_AT_LOGIN, 
            startAtLogin);
        Configurator.setStartAtLogin(startAtLogin);
    }
    public int getPort() {
        return LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
    }
    public ConnectivityStatus getConnectivity() {
        return connectivity;
    }
    public String getLocation() {
        return LanternHub.censored().countryCode();
    }
    public String getVersion() {
        return LanternConstants.VERSION;
    }
    public UpdateData getUpdateData() {
        return updateData;
    }
    public Internet getInternet() {
        return LanternHub.internet();
    }
    public Platform getPlatform() {
        return LanternHub.platform();
    }
    @Override
    public void onUpdate(final UpdateData updateData) {
        this.updateData = updateData;
    }
    @Override
    public void onConnectivityStateChanged(final ConnectivityStatus ct) {
        this.connectivity = ct;
    }
    public void setConnectOnLaunch(final boolean connectOnLaunch) {
        LanternUtils.setBooleanProperty(LanternConstants.CONNECT_ON_LAUNCH, 
                connectOnLaunch);
    }
    public boolean isConnectOnLaunch() {
        return LanternUtils.getBooleanProperty(
            LanternConstants.CONNECT_ON_LAUNCH, true);
    }
}
