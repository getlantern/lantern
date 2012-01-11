package org.lantern;

import java.util.Locale;

import org.codehaus.jackson.annotate.JsonIgnore;

import com.google.common.eventbus.Subscribe;

/**
 * Top level class containing all user settings.
 */
//@JsonPropertyOrder({"user", "system", "whitelist", "roster"})
public class Settings implements MutableSettings {

    //private UserInfo userInfo;
    
    private Whitelist whitelist;
    
    private Roster roster;
    
    private ConnectivityStatus connectivity = 
        ConnectivityStatus.DISCONNECTED; 
    private UpdateEvent update = new UpdateEvent();
    
    private Internet internet = new Internet();
    private Platform platform = new Platform();
    private boolean startAtLogin = true;
    private boolean isSystemProxy = true;
    private int port = LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
    private String version = LanternConstants.VERSION;
    private boolean connectOnLaunch = true;
    private String language = Locale.getDefault().getLanguage();
    
    private SettingsState settings = new SettingsState();
    
    private boolean isBackendRunning = true;
    
    private AuthenticationStatus authenticationStatus = 
        AuthenticationStatus.LOGGED_OUT;
    
    private boolean proxyAllSites;
    
    private Country country = LanternHub.censored().country();
    
    private Country countryDetected = LanternHub.censored().country();
    
    private boolean manuallyOverrideCountry;
    
    private String email;
    
    private String password;
    
    private String storedPassword;
    
    /**
     * Whether or not to save the user's Google account password on disk.
     */
    private boolean savePassword = true;
    
    /**
     * Whether or not Lantern should use our cloud proxies. Users may not want
     * to use Lantern cloud proxies at all if they want more privacy.
     */
    private boolean useCloudProxies = true;
    
    private boolean getMode = LanternHub.censored().isCensored();
    
    private boolean bindToLocalhost = true;
    
    private int apiPort;
    
    
    {
        LanternHub.eventBus().register(this);
    }
    
    public Settings() {
    }
    
    public Settings(final Whitelist whitelist, final Roster roster) {
        this.whitelist = whitelist;
        this.roster = roster;
    }
    
    public Whitelist getWhitelist() {
        //if (this.whitelist == null) {
        //    this.whitelist = LanternHub.settings().whitelist();
       // }
        return whitelist;
    }

    public void setWhitelist(final Whitelist whitelist) {
        this.whitelist = whitelist;
    }

    public void setRoster(final Roster roster) {
        this.roster = roster;
    }

    public Roster getRoster() {
        //if (this.roster == null) {
        //    this.roster = LanternHub.settings().roster();
        //}
        return roster;
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
    
    public void setConnectOnLaunch(final boolean connectOnLaunch) {
        this.connectOnLaunch = connectOnLaunch;
    }
    
    public boolean isConnectOnLaunch() {
        return this.connectOnLaunch;
    }
    
    @Subscribe
    public void onUpdate(final UpdateEvent ue) {
        this.update = ue;
    }
    
    @Subscribe
    public void onConnectivityStateChanged(
        final ConnectivityStatusChangeEvent csce) {
        this.connectivity = csce.getConnectivityStatus();
    }

    public void setLanguage(final String language) {
        this.language = language;
    }

    public String getLanguage() {
        return language;
    }

    public void setUpdate(UpdateEvent update) {
        this.update = update;
    }

    public UpdateEvent getUpdate() {
        return update;
    }

    public void setSettings(SettingsState settings) {
        this.settings = settings;
    }

    public SettingsState getSettings() {
        return settings;
    }

    public void setBackendRunning(final boolean isBackendRunning) {
        this.isBackendRunning = isBackendRunning;
    }

    public boolean isBackendRunning() {
        return isBackendRunning;
    }

    public String getEmail() {
        //return LanternUtils.getEmail();
        return email;
    }

    public void setEmail(final String email) {
        this.email = email;
    }

    public void setAuthenticationStatus(
        final AuthenticationStatus authenticationStatus) {
        // We ignore the value from disk and rely on the event dispatch system.
    }

    public AuthenticationStatus getAuthenticationStatus() {
        return authenticationStatus;
    }
    
    @Subscribe
    public void onAuthenticationStateChanged(
        final AuthenticationStatusEvent ase) {
        this.authenticationStatus = ase.getStatus();
    }

    public void setProxyAllSites(final boolean proxyAllSites) {
        this.proxyAllSites = proxyAllSites;
    }

    public boolean isProxyAllSites() {
        return proxyAllSites;
    }

    public Country getCountry() {
        return this.country;
    }
    
    @Override
    public void setCountry(final Country country) {
        this.country = country;
    }

    public void setManuallyOverrideCountry(
        final boolean manuallyOverrideCountry) {
        this.manuallyOverrideCountry = manuallyOverrideCountry;
    }

    public boolean isManuallyOverrideCountry() {
        return manuallyOverrideCountry;
    }

    public void setSavePassword(final boolean savePassword) {
        this.savePassword = savePassword;
        if (!this.savePassword) {
            setStoredPassword("");
        } else {
            setStoredPassword(password);
        }
    }

    public boolean isSavePassword() {
        return savePassword;
    }

    @JsonIgnore
    public void setPassword(final String password) {
        if (this.isSavePassword()) {
            setStoredPassword(password);
        } else {
            this.password = password;
        }
    }

    @JsonIgnore
    public String getPassword() {
        return password;
    }

    public void setStoredPassword(final String storedPassword) {
        this.storedPassword = storedPassword;
        this.password = storedPassword;
    }

    public String getStoredPassword() {
        return storedPassword;
    }

    public void setUseCloudProxies(final boolean useCloudProxies) {
        this.useCloudProxies = useCloudProxies;
    }

    public boolean isUseCloudProxies() {
        return useCloudProxies;
    }

    @Override
    public void setGetMode(final boolean getMode) {
        this.getMode = getMode;
    }

    public boolean isGetMode() {
        return getMode;
    }

    public void setBindToLocalhost(boolean bindToLocalhost) {
        this.bindToLocalhost = bindToLocalhost;
    }

    public boolean isBindToLocalhost() {
        return bindToLocalhost;
    }

    public void setApiPort(final int apiPort) {
        this.apiPort = apiPort;
    }

    public int getApiPort() {
        return apiPort;
    }

    public void setCountryDetected(Country countryDetected) {
        this.countryDetected = countryDetected;
    }

    public Country getCountryDetected() {
        return countryDetected;
    }

}
