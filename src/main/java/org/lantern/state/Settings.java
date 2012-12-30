package org.lantern.state;

import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;

import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
import org.lantern.Whitelist;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.collect.ImmutableSet;
import com.google.common.collect.Sets;

/**
 * Base Lantern settings.
 */
public class Settings {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private String email = "";
    
    private String lang = Locale.getDefault().getLanguage();
    
    private boolean autoConnect = true;

    private boolean autoReport = true;
    
    private Mode mode = Mode.none;
    
    private int proxyPort = LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
    
    private boolean systemProxy = true;
    
    private boolean proxyAllSites = false;
    
    private boolean useGoogleOAuth2 = false;
    private String clientID;
    private String clientSecret;
    private String accessToken;
    private String refreshToken;
    
    private Set<String> inClosedBeta = new HashSet<String>();
    
    private Whitelist whitelist = new Whitelist();

    private boolean runAtSystemStart = true;

    private Set<String> proxies = new LinkedHashSet<String>();

    private boolean useTrustedPeers = true;

    private boolean useLaeProxies = true;

    private boolean useAnonymousPeers = true;

    private boolean useCentralProxies = true;

    private Set<String> stunServers = new HashSet<String>();

    private int serverPort = LanternUtils.randomPort();

    /**
     * Indicates whether use of keychains is enabled. 
     * this can be disabled by command line option.
     */
    private boolean keychainEnabled = true;

    /**
     * Whether or not we're running with a graphical UI.  
     * Not stored or sent to the browser.
     */
    private boolean uiEnabled = true;
    

    private boolean bindToLocalhost = true;

    //private boolean autoConnectToPeers = true;

    private boolean useCloudProxies = true;
    
    public enum Mode {
        give,
        get, 
        none
    }
    
    @JsonView({Run.class, Persistent.class})
    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    @JsonView(Run.class)
    public String getLang() {
        return lang;
    }

    public void setLang(String lang) {
        this.lang = lang;
    }

    @JsonView({Run.class, Persistent.class})
    public boolean isAutoConnect() {
        return autoConnect;
    }

    public void setAutoConnect(final boolean autoConnect) {
        this.autoConnect = autoConnect;
    }

    @JsonView({Run.class, Persistent.class})
    public boolean isAutoReport() {
        return autoReport;
    }

    public void setAutoReport(final boolean autoReport) {
        this.autoReport = autoReport;
    }

    @JsonView({Run.class, Persistent.class})
    public Mode getMode() {
        return mode;
    }

    public void setMode(final Mode mode) {
        this.mode = mode;
    }

    @JsonView({Run.class, Persistent.class})
    public int getProxyPort() {
        return proxyPort;
    }

    public void setProxyPort(final int proxyPort) {
        this.proxyPort = proxyPort;
    }

    @JsonView({Run.class, Persistent.class})
    public boolean isSystemProxy() {
        return systemProxy;
    }

    public void setSystemProxy(final boolean systemProxy) {
        this.systemProxy = systemProxy;
    }

    @JsonView({Run.class, Persistent.class})
    public boolean isProxyAllSites() {
        return proxyAllSites;
    }

    public void setProxyAllSites(final boolean proxyAllSites) {
        this.proxyAllSites = proxyAllSites;
    }

    @JsonView({Run.class})
    public Collection<String> getProxiedSites() {
        return whitelist.getEntriesAsStrings();
    }

    public void setProxiedSites(final String[] proxiedSites) {
        whitelist.setStringEntries(proxiedSites);
    }

    @JsonView({Persistent.class})
    public Whitelist getWhitelist() {
        return whitelist;
    }

    public void setWhitelist(Whitelist whitelist) {
        this.whitelist = whitelist;
    }
    
    public void setClientID(final String clientID) {
        this.clientID = clientID;
    }

    public void setUseGoogleOAuth2(boolean useGoogleOAuth2) {
        this.useGoogleOAuth2 = useGoogleOAuth2;
    }

    @JsonView({Persistent.class})
    public boolean isUseGoogleOAuth2() {
        return useGoogleOAuth2;
    }

    @JsonView({Persistent.class})
    public String getClientID() {
        return clientID;
    }

    public void setClientSecret(final String clientSecret) {
        this.clientSecret = clientSecret;
    }

    @JsonView({Persistent.class})
    public String getClientSecret() {
        return clientSecret;
    }

    public void setAccessToken(final String accessToken) {
        this.accessToken = accessToken;
    }

    @JsonView({Persistent.class})
    public String getAccessToken() {
        return accessToken;
    }

    public void setRefreshToken(final String refreshToken) {
        this.refreshToken = refreshToken;
    }

    @JsonView({Persistent.class})
    public String getRefreshToken() {
        return refreshToken;
    }
    
    
    @JsonView({Persistent.class})
    public Set<String> getInClosedBeta() {
        return Sets.newHashSet(this.inClosedBeta);
    }

    public void setInClosedBeta(final Set<String> inClosedBeta) {
        this.inClosedBeta = ImmutableSet.copyOf(inClosedBeta);
    }

    public void setProxies(final Set<String> proxies) {
        synchronized (this.proxies) {
            this.proxies = proxies;
        }
    }

    @JsonView({Persistent.class})
    public Set<String> getProxies() {
        synchronized (this.proxies) {
            return ImmutableSet.copyOf(this.proxies);
        }
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
    

    public void setUseTrustedPeers(final boolean useTrustedPeers) {
        this.useTrustedPeers = useTrustedPeers;
    }
    
    @JsonIgnore
    public boolean isUseTrustedPeers() {
        return useTrustedPeers;
    }

    public void setUseLaeProxies(boolean useLaeProxies) {
        this.useLaeProxies = useLaeProxies;
    }

    @JsonIgnore
    public boolean isUseLaeProxies() {
        return useLaeProxies;
    }

    public void setUseAnonymousPeers(boolean useAnonymousPeers) {
        this.useAnonymousPeers = useAnonymousPeers;
    }

    @JsonIgnore
    public boolean isUseAnonymousPeers() {
        return useAnonymousPeers;
    }

    public void setUseCentralProxies(final boolean useCentralProxies) {
        this.useCentralProxies = useCentralProxies;
    }

    @JsonIgnore
    public boolean isUseCentralProxies() {
        return useCentralProxies;
    }
    
    public void setStunServers(final Set<String> stunServers){
        this.stunServers = stunServers;
    }

    @JsonView({Run.class, Persistent.class})
    public Collection<String> getStunServers() {
        return stunServers;
    }
    
    public void setServerPort(final int serverPort) {
        this.serverPort = serverPort;
    }

    @JsonView({Persistent.class})
    public int getServerPort() {
        return serverPort;
    }
    
    public void setKeychainEnabled(boolean keychainEnabled) {
        this.keychainEnabled = keychainEnabled;
    }
    
    @JsonIgnore
    public boolean isKeychainEnabled() {
        return keychainEnabled;
    }
    
    public void setUiEnabled(boolean uiEnabled) {
        this.uiEnabled = uiEnabled;
    }

    @JsonIgnore
    public boolean isUiEnabled() {
        return uiEnabled;
    }
    
    public void setBindToLocalhost(final boolean bindToLocalhost) {
        this.bindToLocalhost = bindToLocalhost;
    }

    @JsonIgnore
    public boolean isBindToLocalhost() {
        return bindToLocalhost;
    }
    
    /*
    public void setAutoConnectToPeers(final boolean autoConnectToPeers) {
        this.autoConnectToPeers = autoConnectToPeers;
    }

    @JsonIgnore
    public boolean isAutoConnectToPeers() {
        return autoConnectToPeers;
    }
    */

    public void setUseCloudProxies(final boolean useCloudProxies) {
        this.useCloudProxies = useCloudProxies;
    }

    @JsonView({Run.class, Persistent.class})
    public boolean isUseCloudProxies() {
        return useCloudProxies;
    }

    public boolean isRunAtSystemStart() {
        return runAtSystemStart;
    }

    @JsonView({Run.class, Persistent.class})
    public void setRunAtSystemStart(boolean runOnSystemStartup) {
        this.runAtSystemStart = runOnSystemStartup;
    }
}
