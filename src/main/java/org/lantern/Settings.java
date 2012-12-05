package org.lantern;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

import org.apache.commons.beanutils.PropertyUtils;
import org.apache.commons.lang3.StringUtils;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.event.Events;
import org.lantern.event.UpdateEvent;
import org.lantern.state.Location;
import org.lantern.state.Transfers;
import org.lantern.state.Version;
import org.lastbamboo.common.stun.client.PublicIpAddress;
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
    public static class PersistentSetting {}
    public static class RuntimeSetting {}
    
    /**
     * Settings that are not sent to the UI or persisted to disk.
     */
    public static class TransientSettings {}

    // by default, if not marked, fields will be serialized in 
    // all of the above classes. To exclude a field from other
    // class mark it as @JsonIgnore

    
    // These settings are controlled from the command line 
    // and survive events that reload the persistent settings
    // (ie resetting and unlocking)
    // 
    // If non-null, they are overlaid on the loaded persistent 
    // settings values. This is necessary to preserve settings 
    // such as the current api port and availability flags for
    // features (ui, keychain, peer types etc) that may preceed 
    // or affect the way settings are loaded and are generally 
    // not expected to change during a single run. They are 
    // generally orthogonal to the persistent settings. 
    //
    // The overrides field may be specified to force overlay 
    // of the setting onto another setting at reload time.
    // This is preferred to having a setting that is persistent 
    // and survives reset to avoid an un-resettable setting.
    //
    @Retention(RetentionPolicy.RUNTIME)
    @Target({ElementType.METHOD})
    public @interface CommandLineOption {
        String override() default "";
    }
    
    private Whitelist whitelist;

    private Map<String, Object> update = new HashMap<String, Object>();
    
    private Platform platform = new Platform();
    private boolean startAtLogin = true;
    private boolean isSystemProxy = true;
    
    private int port = LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
    private int serverPort = LanternUtils.randomPort();
    private boolean connectOnLaunch = true;
    private String language = Locale.getDefault().getLanguage();
    
    private SettingsState settings = new SettingsState();
    
    /**
     * User has completed 'wizard' setup steps. 
     */
    private boolean initialSetupComplete = false;
    
    private boolean autoConnectToPeers = true;
    
    private boolean proxyAllSites;
    
    private final AtomicReference<Country> country = 
        new AtomicReference<Country>();
    
    private final AtomicReference<Country> countryDetected = 
        new AtomicReference<Country>();
    
    private boolean manuallyOverrideCountry;
    
    private String email;
    
    private String commandLineEmail;

    private String password;
    
    private String storedPassword;

    private String commandLinePassword;
    
    /**
     * Whether or not to save the user's Google account password on disk.
     */
    private boolean savePassword = true;
    
    /**
     * Whether or not Lantern should use our cloud proxies. Users may not want
     * to use Lantern cloud proxies at all if they want more privacy.
     */
    private boolean useCloudProxies = true;
    
    private AtomicBoolean getMode = null;
    
    private boolean bindToLocalhost = true;
    
    private int apiPort;
    
    private boolean passwordSaved;
    
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
    
    //private Set<String> proxies = new LinkedHashSet<String>();
    
    private boolean analytics = true;
    
    /**
     * These are cached proxies we've connected to over TCP/SSL.
     */
    private Set<InetSocketAddress> peerProxies = 
        new HashSet<InetSocketAddress>();

    private boolean useTrustedPeers = true;
    private boolean useAnonymousPeers = true;
    private boolean useLaeProxies = true;
    private boolean useCentralProxies = true;

    private final Object getModeLock = new Object();
    
    private Set<String> stunServers = new HashSet<String>();
    
    private int invites = 0;
    
    private boolean cache = false;
    
    private String uiDir = "dashboard/assets";
    
    private String nodeId = String.valueOf(LanternHub.secureRandom().nextLong());
    
    /**
     * Locally-stored set of users we've invited.
     */
    private Set<String> invited = new HashSet<String>();
    
    private Transfers transfers = new Transfers();
    
    //private Connectivity connectivity = new Connectivity();
    
    private final Version version = new Version();
    
    private final Location location = new Location();

    public Settings()  {
        Events.register(this);
        threadPublicIpLookup();
    }

    /*
    private boolean useGoogleOAuth2=false;
    private String clientID;
    private String clientSecret;
    private String accessToken;
    private String refreshToken;
    */

    public Settings(final Whitelist whitelist) {
        this.whitelist = whitelist;
    }
    
    /**
     * We thread this because otherwise looking up our public IP address 
     * over the network can delay the creation of settings altogether. That's
     * problematic if the UI is waiting on them, for example.
     */
    private void threadPublicIpLookup() {
        if (LanternConstants.ON_APP_ENGINE) {
            return;
        }
        final Thread thread = new Thread(new Runnable() {
            @Override
            public void run() {
                // This performs the public IP lookup so by the time we set
                // GET versus GIVE mode we already know the IP and don't have
                // to wait.
                
                // We get the address here to set it in Connectivity.
                final InetAddress ip = 
                    new PublicIpAddress().getPublicIpAddress();
                if (ip == null) {
                    log.info("No IP -- possibly no internet connection");
                    return;
                }
                //connectivity.setIp(ip.getHostAddress());
                
                // The IP is cached at this point.
                final Country count = LanternHub.censored().country();
                if (countryDetected.get() == null) {
                    countryDetected.set(count);
                }
                if (country.get() == null) {
                    country.set(count);
                }
                if (StringUtils.isBlank(location.getCountry())) {
                    location.setCountry(count.getCode());
                }
                
                synchronized (getModeLock) {
                    if (getMode == null) {
                        getMode = new AtomicBoolean(
                            LanternHub.censored().isCensored());
                    }
                }
            }
            
        }, "Public-IP-Lookup-Thread");
        thread.setDaemon(true);
        thread.start();
    }

    /*
    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public boolean isSystemProxy() {
        return this.isSystemProxy;
    }
    
    @Override
    public void setSystemProxy(final boolean isSystemProxy) {
        this.isSystemProxy = isSystemProxy;
    }
    
    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public boolean isStartAtLogin() {
        return this.startAtLogin;
    }
    @Override
    public void setStartAtLogin(final boolean startAtLogin) {
        this.startAtLogin = startAtLogin;
    }
    */

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public int getPort() {
        return this.port;
    }
    
    @Override
    public void setPort(final int port) {
        this.port = port;
    }

    /*
    public void setServerPort(final int serverPort) {
        this.serverPort = serverPort;
    }

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    @CommandLineOption
    public int getServerPort() {
        return serverPort;
    }
    */

    @JsonView(RuntimeSetting.class)
    public Platform getPlatform() {
        return this.platform;
    }
    
    /*
    public void setConnectOnLaunch(final boolean connectOnLaunch) {
        this.connectOnLaunch = connectOnLaunch;
    }
    
    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public boolean isConnectOnLaunch() {
        return this.connectOnLaunch;
    }
    */
    
    @Subscribe
    public void onUpdate(final UpdateEvent ue) {
        log.info("Got update event");
        this.update = ue.getData();
    }

    public void setLanguage(final String language) {
        this.language = language;
    }

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public String getLanguage() {
        return language;
    }

    public void setUpdate(final Map<String, Object> update) {
        this.update = update;
    }
    
    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public Map<String, Object> getUpdate() {
        return update;
    }

    public void setSettings(SettingsState settings) {
        this.settings = settings;
    }

    @JsonView(RuntimeSetting.class)
    public SettingsState getSettings() {
        return settings;
    }

    /*
    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public boolean isInitialSetupComplete() {
        return initialSetupComplete;
    }

    public void setInitialSetupComplete(boolean val) {
        initialSetupComplete = val;
    }
    */

    /*
    public void setCommandLineEmail(String email) {
        commandLineEmail = email;
    }

    @JsonIgnore
    @CommandLineOption(override="email")
    public String getCommandLineEmail() {
        return commandLineEmail;
    }
    */

    /*
    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public String getEmail() {
        return email;
    }

    @Override
    public void setEmail(final String email) {
        this.email = email;
    }
    */

    /*
    @Override
    public void setProxyAllSites(final boolean proxyAllSites) {
        this.proxyAllSites = proxyAllSites;
    }

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public boolean isProxyAllSites() {
        return proxyAllSites;
    }
    */

    public void setCountryDetected(final Country countryDetected) {
        this.countryDetected.set(countryDetected);
    }

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public Country getCountryDetected() {
        return countryDetected.get();
    }

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
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

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public boolean isManuallyOverrideCountry() {
        return manuallyOverrideCountry;
    }
/*
    @Override
    public void setSavePassword(final boolean savePassword) {
        this.savePassword = savePassword;
    }

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
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
    */

    public void setCommandLinePassword(String password) {
        commandLinePassword = password;
    }

    @JsonIgnore
    @CommandLineOption(override="password")
    public String getCommandLinePassword() {
        return commandLinePassword;
    }

    public void setStoredPassword(final String storedPassword) {
        this.storedPassword = storedPassword;
    }

    @JsonView(PersistentSetting.class)
    public String getStoredPassword() {
        return storedPassword;
    }

    /*
    @JsonIgnore
    public void setClientID(final String clientID) {
        this.clientID = clientID;
    }

    @JsonIgnore
    public void setUseGoogleOAuth2(boolean useGoogleOAuth2) {
        this.useGoogleOAuth2 = useGoogleOAuth2;
    }

    @CommandLineOption
    @JsonIgnore
    public boolean isUseGoogleOAuth2() {
        return useGoogleOAuth2;
    }

    @CommandLineOption
    @JsonIgnore
    public String getClientID() {
        return clientID;
    }

    @JsonIgnore
    public void setClientSecret(final String clientSecret) {
        this.clientSecret = clientSecret;
    }

    @CommandLineOption
    @JsonIgnore
    public String getClientSecret() {
        return clientSecret;
    }

    @JsonIgnore
    public void setAccessToken(final String accessToken) {
        this.accessToken = accessToken;
    }

    @CommandLineOption
    @JsonIgnore
    public String getAccessToken() {
        return accessToken;
    }

    @JsonIgnore
    public void setRefreshToken(final String password) {
        this.refreshToken = password;
    }

    @CommandLineOption
    @JsonIgnore
    public String getRefreshToken() {
        return refreshToken;
    }
    */

    public void setUseCloudProxies(final boolean useCloudProxies) {
        this.useCloudProxies = useCloudProxies;
    }

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public boolean isUseCloudProxies() {
        return useCloudProxies;
    }

    /*
    @Override
    public void setGetMode(final boolean getMode) {
        synchronized (getModeLock) {
            if (this.getMode == null) {
                this.getMode = new AtomicBoolean(getMode);
            } else {
                this.getMode.set(getMode);
            }
        }
    }

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public boolean isGetMode() {
        synchronized (getModeLock) {
            if (getMode == null) {
                getMode = new AtomicBoolean(LanternHub.censored().isCensored());
            } 
            return getMode.get();
        }
    }
    */

    /*
    public void setBindToLocalhost(final boolean bindToLocalhost) {
        this.bindToLocalhost = bindToLocalhost;
    }

    @JsonView({RuntimeSetting.class})
    @CommandLineOption
    public boolean isBindToLocalhost() {
        return bindToLocalhost;
    }
    */
    
    @JsonView(RuntimeSetting.class)
    public boolean isProxying() {
        //return Proxifier.isProxying();
        return false;
    }

    public void setPasswordSaved(boolean passwordSaved) {
        this.passwordSaved = passwordSaved;
    }
    
    @JsonView({RuntimeSetting.class, PersistentSetting.class})
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

    @JsonView(PersistentSetting.class)
    public Whitelist getWhitelist() {
        return whitelist;
    }
    
    /*
    public void setLaunchd(final boolean launchd) {
        this.launchd = launchd;
    }

    @JsonIgnore
    @CommandLineOption
    public boolean isLaunchd() {
        return launchd;
    }
    */
    
    /*
    public void setUiEnabled(boolean uiEnabled) {
        this.uiEnabled = uiEnabled;
    }

    @JsonIgnore
    @CommandLineOption
    public boolean isUiEnabled() {
        return uiEnabled;
    }
    */
    
    /*
    public void setKeychainEnabled(boolean keychainEnabled) {
        this.keychainEnabled = keychainEnabled;
    }
    public boolean isKeychainEnabled() {
        return keychainEnabled;
    }
    */

    @JsonView(RuntimeSetting.class)
    public boolean isLocalPasswordInitialized() {
        //return LanternHub.localCipherProvider().isInitialized();
        throw new UnsupportedOperationException("FIX ME - NEW UI");
    }

    public void setAutoConnectToPeers(final boolean autoConnectToPeers) {
        this.autoConnectToPeers = autoConnectToPeers;
    }

    @JsonView(TransientSettings.class)
    public boolean isAutoConnectToPeers() {
        return autoConnectToPeers;
    }

    /*
    public void addProxy(final String proxy) {
        // Don't store peer proxies on disk.
        if (!proxy.contains("@")) {
            this.proxies.add(proxy);
        }
    }

    public void removeProxy(final String proxy) {
        this.proxies.remove(proxy);
    }
    */
    
    /*
    public void setProxies(final Set<String> proxies) {
        synchronized (this.proxies) {
            this.proxies = proxies;
        }
    }

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public Set<String> getProxies() {
        synchronized (this.proxies) {
            return ImmutableSet.copyOf(this.proxies);
        }
    }
    */
    
    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public Set<InetSocketAddress> getPeerProxies() {
        synchronized (this.peerProxies) {
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
    
/*
    public void setUseTrustedPeers(final boolean useTrustedPeers) {
        this.useTrustedPeers = useTrustedPeers;
    }
    
    @JsonView({RuntimeSetting.class})
    @CommandLineOption
    public boolean isUseTrustedPeers() {
        return useTrustedPeers;
    }

    public void setUseLaeProxies(boolean useLaeProxies) {
        this.useLaeProxies = useLaeProxies;
    }

    @JsonView({RuntimeSetting.class})
    @CommandLineOption
    public boolean isUseLaeProxies() {
        return useLaeProxies;
    }

    public void setUseAnonymousPeers(boolean useAnonymousPeers) {
        this.useAnonymousPeers = useAnonymousPeers;
    }

    @JsonView({RuntimeSetting.class})
    @CommandLineOption
    public boolean isUseAnonymousPeers() {
        return useAnonymousPeers;
    }

    public void setUseCentralProxies(final boolean useCentralProxies) {
        this.useCentralProxies = useCentralProxies;
    }

    @JsonView({RuntimeSetting.class})
    @CommandLineOption
    public boolean isUseCentralProxies() {
        return useCentralProxies;
    }
    
    public void setStunServers(final Set<String> stunServers){
        this.stunServers = stunServers;
    }

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public Collection<String> getStunServers() {
        return stunServers;
    }

    public void setAnalytics(final boolean analytics) {
        this.analytics = analytics;
    }

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public boolean isAnalytics() {
        return analytics;
    }
    */
    
    public void setInvited(final Set<String> invited) {
        this.invited = invited;
    }
    
    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public Set<String> getInvited() {
        return invited;
    }

    public void setUiDir(final String uiDir) {
        this.uiDir = uiDir;
    }

    @JsonIgnore
    public String getUiDir() {
        return uiDir;
    }

    /*
    public void setCache(final boolean cache) {
        this.cache = cache;
    }

    @JsonIgnore
    public boolean isCache() {
        return cache;
    }
    */

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public Transfers getTransfers() {
        return transfers;
    }

    public void setTransfers(Transfers transfers) {
        this.transfers = transfers;
    }

    @JsonView(RuntimeSetting.class)
    public Version getVersion() {
        return version;
    }

    @JsonView({PersistentSetting.class})
    public String getNodeId() {
        return nodeId;
    }

    public void setNodeId(final String nodeId) {
        this.nodeId = nodeId;
    }
    
    @Override
    public String toString() {
        return "Settings [update=" + update + ", platform=" + platform
                + ", startAtLogin=" + startAtLogin + ", isSystemProxy="
                + isSystemProxy + ", port=" + port + ", serverPort="
                + serverPort + ", version=" + getVersion() + ", connectOnLaunch="
                + connectOnLaunch + ", language=" + language + ", settings="
                + settings + ", initialSetupComplete=" + initialSetupComplete
                + ", autoConnectToPeers=" + autoConnectToPeers
                + ", proxyAllSites=" + proxyAllSites + ", country=" + country
                + ", countryDetected=" + countryDetected
                + ", manuallyOverrideCountry=" + manuallyOverrideCountry
                + ", email=" + email + ", commandLineEmail=" + commandLineEmail
                + ", password=" + password + ", storedPassword="
                + storedPassword + ", commandLinePassword="
                + commandLinePassword + ", savePassword=" + savePassword
                + ", useCloudProxies=" + useCloudProxies + ", getMode="
                + getMode + ", bindToLocalhost=" + bindToLocalhost
                + ", apiPort=" + apiPort + ", passwordSaved=" + passwordSaved
                + ", launchd=" + launchd + ", uiEnabled=" + uiEnabled
                + ", keychainEnabled=" + keychainEnabled 
                + ", analytics=" + analytics + ", peerProxies="
                + peerProxies + ", useTrustedPeers=" + useTrustedPeers
                + ", useAnonymousPeers=" + useAnonymousPeers
                + ", useLaeProxies=" + useLaeProxies + ", useCentralProxies="
                + useCentralProxies + ", getModeLock=" + getModeLock
                + ", stunServers=" + stunServers + ", invites=" + invites
                + ", cache=" + cache + ", uiDir=" + uiDir
                + ", nodeId=" + nodeId + ", invited=" + invited
                + ", transfers=" + transfers 
                + "]";
    }

    /** 
     * copy properties annotated with the CommandLineOption setting 
     * from this Settings object to the Settings object given. 
     * 
     * copy is shallow!
     */
    public void copyCLI(Settings into)
        throws IllegalAccessException, IllegalArgumentException, 
               InvocationTargetException, NoSuchMethodException {
        for (final Method method : Settings.class.getMethods()) {
            if (method.isAnnotationPresent(CommandLineOption.class)) {
                final CommandLineOption v = method.getAnnotation(CommandLineOption.class);
                final String propertyName = LanternUtils.methodNameToProperty(method.getName());
                if (propertyName != null) {
                    Object val = PropertyUtils.getSimpleProperty(this, propertyName);
                    if (val != null) {

                        PropertyUtils.setSimpleProperty(into, propertyName, val);
                        log.debug("copied setting {}", propertyName);
                        
                        final String override = v.override();
                        if (!override.equals("")) {
                            PropertyUtils.setSimpleProperty(into, override, val);
                            log.debug("override setting {} = {}", override, propertyName);
                        }
                    }
                }
                else {
                    log.error("Skipping copy of annotated but unbeanish method \"{}\": can't determine prop name", method.getName());
                }
            }
        }
    }
}
