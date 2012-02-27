package org.lantern;

import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Map;

import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.httpseverywhere.HttpsEverywhere;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

/**
 * Top level class containing all user settings.
 */
public class Settings implements MutableSettings {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    // marker class used to indicate settings that are 
    // saved / loaded between runs of lantern.
    public static class PersistentSettings {}
    public static class UIStateSettings {}

    private Whitelist whitelist;
    
    private ConnectivityStatus connectivity = ConnectivityStatus.DISCONNECTED; 
    private Map<String, Object> update = new HashMap<String, Object>();
    
    private Internet internet = new Internet();
    private Platform platform = new Platform();
    private boolean startAtLogin = true;
    private boolean isSystemProxy = true;
    
    private int port = LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
    private String version = LanternConstants.VERSION;
    private boolean connectOnLaunch = true;
    private String language = Locale.getDefault().getLanguage();
    
    private SettingsState settings = new SettingsState();
    /* user has completed 'wizard' setup steps */
    private boolean initialSetupComplete = false;
    
    private AuthenticationStatus authenticationStatus = 
        AuthenticationStatus.LOGGED_OUT;
    
    private boolean proxyAllSites;
    
    private Country country;
    
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
    
    private boolean passwordSaved;
    
    // sum of past runs
    private long historicalUpBytes = 0;
    private long historicalDownBytes = 0;
    
    /**
     * Whether or not we're running from launchd. Not stored or sent to the 
     * browser.
     */
    private boolean launchd = false;

    /**
     * Whether or not we're running with a graphical UI.  
     * Not stored or sent to the browser.
     */
    private boolean uiEnabled = true;
    
    
    private Collection<String> proxies = new LinkedHashSet<String>();
    
    {
        LanternHub.register(this);
    }
    
    public Settings() {}
    
    public Settings(final Whitelist whitelist) {
        this.whitelist = whitelist;
    }

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isSystemProxy() {
        return this.isSystemProxy;
    }
    
    @Override
    public void setSystemProxy(final boolean isSystemProxy) {
        this.isSystemProxy = isSystemProxy;
    }
    
    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isStartAtLogin() {
        return this.startAtLogin;
    }
    @Override
    public void setStartAtLogin(final boolean startAtLogin) {
        this.startAtLogin = startAtLogin;
    }
    

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public int getPort() {
        return this.port;
    }
    
    @Override
    public void setPort(final int port) {
        this.port = port;
    }
    
    @JsonView(UIStateSettings.class)
    public ConnectivityStatus getConnectivity() {
        return connectivity;
    }

    @JsonView(UIStateSettings.class)
    public String getVersion() {
        return this.version;
    }
    
    @JsonView(UIStateSettings.class)
    public Internet getInternet() {
        return internet;
    }

    @JsonView(UIStateSettings.class)
    public Platform getPlatform() {
        return this.platform;
    }
    
    public void setConnectOnLaunch(final boolean connectOnLaunch) {
        this.connectOnLaunch = connectOnLaunch;
    }
    
    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isConnectOnLaunch() {
        return this.connectOnLaunch;
    }
    
    @Subscribe
    public void onUpdate(final UpdateEvent ue) {
        log.info("Got update event");
        this.update = ue.getData();
    }
    
    @Subscribe
    public void onConnectivityStateChanged(
        final ConnectivityStatusChangeEvent csce) {
        log.info("Received connectivity changed event");
        this.connectivity = csce.getConnectivityStatus();
    }

    public void setLanguage(final String language) {
        this.language = language;
    }

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public String getLanguage() {
        return language;
    }

    public void setUpdate(final Map<String, Object> update) {
        this.update = update;
    }
    
    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public Map<String, Object> getUpdate() {
        return update;
    }

    public void setSettings(SettingsState settings) {
        this.settings = settings;
    }

    @JsonView(UIStateSettings.class)
    public SettingsState getSettings() {
        return settings;
    }

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isInitialSetupComplete() {
        return initialSetupComplete;
    }

    public void setInitialSetupComplete(boolean val) {
        initialSetupComplete = val;
    }

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public String getEmail() {
        return email;
    }

    @Override
    public void setEmail(final String email) {
        this.email = email;
    }

    @JsonView(UIStateSettings.class)
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

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isProxyAllSites() {
        return proxyAllSites;
    }


    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public Country getCountry() {
        if (this.country == null) {
            this.country = LanternHub.censored().country();
        }
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

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isManuallyOverrideCountry() {
        return manuallyOverrideCountry;
    }

    public void setSavePassword(final boolean savePassword) {
        this.savePassword = savePassword;
    }

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isSavePassword() {
        return savePassword;
    }

    @Override
    @JsonIgnore
    public void setPassword(final String password) {
        this.password = password;
    }

    @JsonIgnore
    public String getPassword() {
        return password;
    }

    public void setStoredPassword(final String storedPassword) {
        this.storedPassword = storedPassword;
    }

    @JsonView(PersistentSettings.class)
    public String getStoredPassword() {
        return storedPassword;
    }

    public void setUseCloudProxies(final boolean useCloudProxies) {
        this.useCloudProxies = useCloudProxies;
    }


    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isUseCloudProxies() {
        return useCloudProxies;
    }

    @Override
    public void setGetMode(final boolean getMode) {
        this.getMode = getMode;
    }


    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isGetMode() {
        return getMode;
    }

    public void setBindToLocalhost(boolean bindToLocalhost) {
        this.bindToLocalhost = bindToLocalhost;
    }


    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isBindToLocalhost() {
        return bindToLocalhost;
    }

    public void setApiPort(final int apiPort) {
        this.apiPort = apiPort;
    }


    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public int getApiPort() {
        return apiPort;
    }

    public void setCountryDetected(Country countryDetected) {
        this.countryDetected = countryDetected;
    }

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public Country getCountryDetected() {
        return countryDetected;
    }

    @JsonView(UIStateSettings.class)
    public long getPeerCount() {
        return LanternHub.statsTracker().getPeerCount();
    }

    @JsonView(UIStateSettings.class)
    public long getPeerCountThisRun() {
        return LanternHub.statsTracker().getPeerCountThisRun();
    }

    @JsonView(UIStateSettings.class)
    public long getUpRate() {
        return LanternHub.statsTracker().getUpBytesPerSecond();
    }
    
    @JsonView(UIStateSettings.class)
    public long getDownRate() {
        return LanternHub.statsTracker().getDownBytesPerSecond();
    }
    
    @JsonView(UIStateSettings.class)
    public long getUpTotalThisRun() {
        return LanternHub.statsTracker().getUpBytesThisRun();
    }
    
    @JsonView(UIStateSettings.class)
    public long getDownTotalThisRun() {
        return LanternHub.statsTracker().getDownBytesThisRun();
    }
    
    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public long getUpTotalLifetime() {
        return getUpTotalThisRun() + historicalUpBytes;
    }

    public void setUpTotalLifetime(long value) {
        historicalUpBytes = value;
    }

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public long getDownTotalLifetime() {
        return getDownTotalThisRun() + historicalDownBytes;
    }

    public void setDownTotalLifetime(long value) {
        historicalDownBytes = value;
    }
    
    @JsonView(UIStateSettings.class)
    public boolean isProxying() {
        return Proxifier.isProxying();
    }

    public void setPasswordSaved(boolean passwordSaved) {
        this.passwordSaved = passwordSaved;
    }
    
    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isPasswordSaved() {
        return passwordSaved;
    }

    @JsonView(UIStateSettings.class)
    public HttpsEverywhere getHttpsEverywhere() {
        return LanternHub.httpsEverywhere();
    }
    
    public void setWhitelist(Whitelist whitelist) {
        this.whitelist = whitelist;
    }

    @JsonView(PersistentSettings.class)
    public Whitelist getWhitelist() {
        return whitelist;
    }
    

    public void setLaunchd(final boolean launchd) {
        this.launchd = launchd;
    }

    public boolean isLaunchd() {
        return launchd;
    }
    

    public void setUiEnabled(boolean uiEnabled) {
        this.uiEnabled = uiEnabled;
    }
    
    public boolean isUiEnabled() {
        return uiEnabled;
    }

    public void addProxy(final String proxy) {
        this.proxies.add(proxy);
    }
    
    public void setProxies(Collection<String> proxies) {
        this.proxies = proxies;
    }

    public Collection<String> getProxies() {
        return proxies;
    }

    @Override
    public String toString() {
        return "Settings [connectivity=" + connectivity 
                + ", update=" + update
                + ", internet=" + internet + ", platform=" + platform
                + ", startAtLogin=" + startAtLogin + ", isSystemProxy="
                + isSystemProxy + ", port=" + port + ", version=" + version
                + ", connectOnLaunch=" + connectOnLaunch + ", language="
                + language + ", settings=" + settings
                + ", authenticationStatus=" + authenticationStatus
                + ", proxyAllSites=" + proxyAllSites + ", country=" + country
                + ", countryDetected=" + countryDetected
                + ", manuallyOverrideCountry=" + manuallyOverrideCountry
                + ", email=" + email + ", password=" + password
                + ", storedPassword=" + storedPassword + ", savePassword="
                + savePassword + ", useCloudProxies=" + useCloudProxies
                + ", getMode=" + getMode + ", bindToLocalhost="
                + bindToLocalhost + ", apiPort=" + apiPort + ", passwordSaved="
                + passwordSaved + "]";
    }
}
