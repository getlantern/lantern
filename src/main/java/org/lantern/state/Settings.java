package org.lantern.state;

import java.util.Collection;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
import org.lantern.Whitelist;
import org.lantern.annotation.Keep;
import org.lantern.event.Events;
import org.lantern.event.SystemProxyChangedEvent;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;
import org.littleshoot.proxy.TransportProtocol;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.collect.ImmutableSet;
import com.google.common.collect.Sets;

/**
 * Base Lantern settings.
 */
@Keep
public class Settings {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private String lang = Locale.getDefault().getLanguage();

    private boolean autoReport = true;

    private int proxyPort = LanternConstants.LANTERN_LOCALHOST_HTTP_PORT;
    
    private TransportProtocol proxyProtocol = TransportProtocol.TCP;
    
    private String proxyAuthToken;

    private boolean systemProxy = true;

    private boolean proxyAllSites = false;

    private boolean useGoogleOAuth2 = false;
    private String clientID;
    private String clientSecret;
    private String accessToken;
    private String refreshToken;
    
    private long expiryTime;

    private Set<String> inClosedBeta = new HashSet<String>();

    private Whitelist whitelist = new Whitelist();

    private boolean runAtSystemStart = true;

    private boolean useTrustedPeers = true;

    private boolean useLaeProxies = true;

    private boolean useAnonymousPeers = true;

    private boolean useCentralProxies = true;

    private boolean tcp = true;

    private boolean udp = true;

    private Set<String> stunServers = new HashSet<String>();

    private int serverPort = LanternUtils.randomPort();
    
    private UDPProxyPriority udpProxyPriority = UDPProxyPriority.LOWER;

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

    private boolean showFriendPrompts = true;

    private String configUrl;
    
    public Settings() {
        whitelist.applyDefaultEntries();
    }

    @JsonView(Run.class)
    public String getLang() {
        return lang;
    }

    public void setLang(String lang) {
        this.lang = lang;
    }

    @JsonView({Run.class, Persistent.class})
    public boolean isAutoReport() {
        return autoReport;
    }

    public void setAutoReport(final boolean autoReport) {
        this.autoReport = autoReport;
    }

    @JsonView({Run.class, Persistent.class})
    public int getProxyPort() {
        return proxyPort;
    }
    
    public void setProxyPort(final int proxyPort) {
        this.proxyPort = proxyPort;
    }
    
    @JsonView({Run.class, Persistent.class})
    public TransportProtocol getProxyProtocol() {
        return proxyProtocol;
    }
    
    public void setProxyProtocol(TransportProtocol proxyProtocol) {
        this.proxyProtocol = proxyProtocol;
    }
    
    @JsonView({Run.class, Persistent.class})
    public String getProxyAuthToken() {
        return proxyAuthToken;
    }
    
    public void setProxyAuthToken(String proxyAuthToken) {
        this.proxyAuthToken = proxyAuthToken;
    }

    @JsonView({Run.class, Persistent.class})
    public boolean isSystemProxy() {
        return systemProxy;
    }

    public void setSystemProxy(final boolean systemProxy) {
        log.info("Setting system proxy...");
        this.systemProxy = systemProxy;
        Events.inOrderAsyncEventBus().post(new SystemProxyChangedEvent(systemProxy));
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
        // After the whitelist has been set, apply the default entries
        this.whitelist.applyDefaultEntries();
    }


    public void setUseGoogleOAuth2(boolean useGoogleOAuth2) {
        this.useGoogleOAuth2 = useGoogleOAuth2;
    }

    @JsonView({Persistent.class})
    public boolean isUseGoogleOAuth2() {
        return useGoogleOAuth2;
    }

    public void setClientID(final String clientID) {
        this.clientID = clientID;
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
    public long getExpiryTime() {
        return expiryTime;
    }

    /**
     * This is the access token expiry time.
     * 
     * @param expiryTime The access token expiry time.
     */
    public void setExpiryTime(final long expiryTime) {
        this.expiryTime = expiryTime;
    }

    @JsonView({Persistent.class})
    public Set<String> getInClosedBeta() {
        return Sets.newHashSet(this.inClosedBeta);
    }

    public void setInClosedBeta(final Set<String> inClosedBeta) {
        this.inClosedBeta = ImmutableSet.copyOf(inClosedBeta);
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
    public void setRunAtSystemStart(boolean runAtSystemStart) {
        this.runAtSystemStart = runAtSystemStart;
    }

    @JsonIgnore
    public boolean isTcp() {
        return tcp;
    }

    public void setTcp(boolean tcp) {
        this.tcp = tcp;
    }

    @JsonIgnore
    public boolean isUdp() {
        return udp;
    }

    public void setUdp(boolean udp) {
        this.udp = udp;
    }
    
    @JsonIgnore
    public void setUdpProxyPriority(String priorityString) {
        try {
            this.udpProxyPriority = UDPProxyPriority.valueOf(priorityString);
        } catch (Exception e) {
            log.warn("Invalid proxy priority specified");
        }
    }
    
    public UDPProxyPriority getUdpProxyPriority() {
        return udpProxyPriority;
    }

    public boolean isShowFriendPrompts() {
        return showFriendPrompts;
    }

    @JsonView({Run.class, Persistent.class})
    public void setShowFriendPrompts(boolean showFriendPrompts) {
        this.showFriendPrompts = showFriendPrompts;
    }

    @JsonView({Run.class, Persistent.class})
    public String getConfigUrl() {
        return configUrl;
    }

    public void setConfigUrl(String configUrl) {
        this.configUrl = configUrl;
    }
}
