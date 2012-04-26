package org.lantern;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.InetSocketAddress;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

import org.apache.commons.beanutils.PropertyUtils;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonView;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.collect.ImmutableSet;
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
    
    // settings that are set at the command line
    public static class CommandLineSettings {}
    
    // by default, if not marked, fields will be serialized in 
    // any of the above. To exclude a field from any other class
    // mark it as transient/internal
    public static class TransientInternalOnly {} 

    private Whitelist whitelist;
    
    private ConnectivityStatus connectivity = ConnectivityStatus.DISCONNECTED; 
    private Map<String, Object> update = new HashMap<String, Object>();
    
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
    
    private GoogleTalkState googleTalkState = 
        GoogleTalkState.LOGGED_OUT;
    
    private boolean proxyAllSites;
    
    private final AtomicReference<Country> country = 
        new AtomicReference<Country>();
    
    private final AtomicReference<Country> countryDetected = 
        new AtomicReference<Country>();
    
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
    
    private final AtomicBoolean getMode = new AtomicBoolean(true);
    
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
    
    /**
     * Indicates whether use of keychains is enabled. 
     * this can be disabled by command line option.
     */
    private boolean keychainEnabled = true;
    
    private Set<String> proxies = new LinkedHashSet<String>();
    
    /**
     * These are cached proxies we've connected to over TCP/SSL.
     */
    private Set<InetSocketAddress> peerProxies = 
        new HashSet<InetSocketAddress>();

    private boolean useTrustedPeers = true;
    private boolean useAnonymousPeers = true;
    private boolean useLaeProxies = true;
    private boolean useCentralProxies = true;

    {
        LanternHub.register(this);
        threadPublicIpLookup();
    }
    
    public Settings() {}
    
    public Settings(final Whitelist whitelist) {
        this.whitelist = whitelist;
    }
    
    /**
     * We thread this because otherwise looking up our public IP address 
     * over the network can delay the creation of settings altogether. That's
     * problematic if the UI is waiting on them, for example.
     */
    private void threadPublicIpLookup() {
        final Thread thread = new Thread(new Runnable() {

            @Override
            public void run() {
                getMode.set(LanternHub.censored().isCensored());
                final Country count = LanternHub.censored().country();
                if (countryDetected.get() == null) {
                    countryDetected.set(count);
                }
                if (country.get() == null) {
                    country.set(count);
                }
            }
            
        }, "Public-IP-Lookup-Thread");
        thread.setDaemon(true);
        thread.start();
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

    @JsonView({UIStateSettings.class, PersistentSettings.class, CommandLineSettings.class})
    public String getEmail() {
        return email;
    }

    @Override
    public void setEmail(final String email) {
        this.email = email;
    }

    @JsonView(UIStateSettings.class)
    public GoogleTalkState getGoogleTalkState() {
        return googleTalkState;
    }
    
    @Subscribe
    public void onAuthenticationStateChanged(
        final GoogleTalkStateEvent ase) {
        this.googleTalkState = ase.getState();
    }

    public void setProxyAllSites(final boolean proxyAllSites) {
        this.proxyAllSites = proxyAllSites;
    }

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isProxyAllSites() {
        return proxyAllSites;
    }

    public void setCountryDetected(final Country countryDetected) {
        this.countryDetected.set(countryDetected);
    }

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public Country getCountryDetected() {
        return countryDetected.get();
    }

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public Country getCountry() {
        return this.country.get();
    }
    
    @Override
    public void setCountry(final Country country) {
        this.country.set(country);
    }

    public void setManuallyOverrideCountry(
        final boolean manuallyOverrideCountry) {
        this.manuallyOverrideCountry = manuallyOverrideCountry;
    }

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isManuallyOverrideCountry() {
        return manuallyOverrideCountry;
    }

    @Override
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
    @JsonView({CommandLineSettings.class})
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
        this.getMode.set(getMode);
    }


    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public boolean isGetMode() {
        return getMode.get();
    }

    public void setBindToLocalhost(boolean bindToLocalhost) {
        this.bindToLocalhost = bindToLocalhost;
    }


    @JsonView({UIStateSettings.class, CommandLineSettings.class})
    public boolean isBindToLocalhost() {
        return bindToLocalhost;
    }

    public void setApiPort(final int apiPort) {
        this.apiPort = apiPort;
    }


    @JsonView({UIStateSettings.class, CommandLineSettings.class})
    public int getApiPort() {
        return apiPort;
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

    /*
    @JsonView(UIStateSettings.class)
    public HttpsEverywhere getHttpsEverywhere() {
        return LanternHub.httpsEverywhere();
    }
    */
    
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

    @JsonView(CommandLineSettings.class)
    public boolean isLaunchd() {
        return launchd;
    }
    
    public void setUiEnabled(boolean uiEnabled) {
        this.uiEnabled = uiEnabled;
    }

    @JsonView(CommandLineSettings.class)    
    public boolean isUiEnabled() {
        return uiEnabled;
    }
    
    public void setKeychainEnabled(boolean keychainEnabled) {
        this.keychainEnabled = keychainEnabled;
    }
    public boolean isKeychainEnabled() {
        return keychainEnabled;
    }

    @JsonView(UIStateSettings.class)
    public boolean isLocalPasswordInitialized() {
        return LanternHub.localCipherProvider().isInitialized();
    }

    public void addProxy(final String proxy) {
        // Don't store peer proxies on disk.
        if (!proxy.contains("@")) {
            this.proxies.add(proxy);
        }
    }

    public void removeProxy(final String proxy) {
        this.proxies.remove(proxy);
    }
    
    public void setProxies(final Set<String> proxies) {
        synchronized (this.proxies) {
            this.proxies = proxies;
        }
    }

    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public Set<String> getProxies() {
        synchronized (this.proxies) {
            return ImmutableSet.copyOf(this.proxies);
        }
    }
    
    @JsonView({UIStateSettings.class, PersistentSettings.class})
    public Set<InetSocketAddress> getPeerProxies() {
        synchronized (this.proxies) {
            return ImmutableSet.copyOf(this.peerProxies);
        }
    }

    public void setPeerProxies(final Set<InetSocketAddress> peerProxies) {
        synchronized (this.peerProxies) {
            this.peerProxies = peerProxies;
        }
    }
    
    public void addPeerProxy(final InetSocketAddress proxy) {
        this.peerProxies.add(proxy);
    }
    
    public void removePeerProxy(final InetSocketAddress proxy) {
        this.peerProxies.remove(proxy);
    }
    

    public void setUseTrustedPeers(final boolean useTrustedPeers) {
        this.useTrustedPeers = useTrustedPeers;
    }
    
    @JsonView({UIStateSettings.class, CommandLineSettings.class})
    public boolean isUseTrustedPeers() {
        return useTrustedPeers;
    }

    public void setUseLaeProxies(boolean useLaeProxies) {
        this.useLaeProxies = useLaeProxies;
    }

    @JsonView({UIStateSettings.class, CommandLineSettings.class})
    public boolean isUseLaeProxies() {
        return useLaeProxies;
    }

    public void setUseAnonymousPeers(boolean useAnonymousPeers) {
        this.useAnonymousPeers = useAnonymousPeers;
    }

    @JsonView({UIStateSettings.class, CommandLineSettings.class})
    public boolean isUseAnonymousPeers() {
        return useAnonymousPeers;
    }

    public void setUseCentralProxies(boolean useCentralProxies) {
        this.useCentralProxies = useCentralProxies;
    }

    @JsonView({UIStateSettings.class, CommandLineSettings.class})
    public boolean isUseCentralProxies() {
        return useCentralProxies;
    }

    @Override
    public String toString() {
        return "Settings [" 
                + "connectivity=" + connectivity + ", update=" + update
                + ", platform=" + platform
                + ", startAtLogin=" + startAtLogin + ", isSystemProxy="
                + isSystemProxy + ", port=" + port + ", version=" + version
                + ", connectOnLaunch=" + connectOnLaunch + ", language="
                + language + ", settings=" + settings
                + ", initialSetupComplete=" + initialSetupComplete
                + ", googleTalkState=" + googleTalkState
                + ", proxyAllSites=" + proxyAllSites + ", country=" + country
                + ", countryDetected=" + countryDetected
                + ", manuallyOverrideCountry=" + manuallyOverrideCountry
                + ", savePassword=" + savePassword + ", useCloudProxies="
                + useCloudProxies + ", getMode=" + getMode
                + ", bindToLocalhost=" + bindToLocalhost + ", apiPort="
                + apiPort + ", passwordSaved=" + passwordSaved
                + ", historicalUpBytes=" + historicalUpBytes
                + ", historicalDownBytes=" + historicalDownBytes + ", launchd="
                + launchd + ", uiEnabled=" + uiEnabled + "]";
    }
    
    /** 
     * copy properties annotated with the given jsonView class 
     * from this Settings object to the Settings object given. 
     * 
     * copy is shallow!
     */
    public void copyView(Settings into, Class<?> selector)
        throws IllegalAccessException, IllegalArgumentException, 
               InvocationTargetException, NoSuchMethodException {
        for (final Method method : Settings.class.getMethods()) {
            if (method.isAnnotationPresent(JsonView.class)) {
                final JsonView v = method.getAnnotation(JsonView.class);
                for (final Class<?> c : v.value()) {
                    if (c == selector) {
                        // method is annotated with selected JsonView
                        // try to transfer property.
                        final String propertyName = LanternUtils.methodNameToProperty(method.getName()); 
                        if (propertyName != null) {
                            PropertyUtils.setSimpleProperty(into, propertyName,
                                PropertyUtils.getSimpleProperty(this, propertyName));
                            log.debug("copied setting {}", propertyName);
                        }
                        else {
                            log.error("Skipping copy of annotated but unbeanish method \"{}\": can't determine prop name", method.getName());
                        }
                    }
                }
            }
        }
        
    }
}
