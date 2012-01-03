package org.lantern;

import org.apache.commons.lang.StringUtils;

import com.google.common.eventbus.Subscribe;

/**
 * Data about the user.
 */
public class UserInfo implements MutableUserSettings {
    
    private AuthenticationStatus authenticationStatus = 
        AuthenticationStatus.LOGGED_OUT;
    
    private ConnectivityStatus connectivityStatus = 
        ConnectivityStatus.DISCONNECTED;

    private String mode;
    
    private boolean proxyAllSites;
    
    private Country country = LanternHub.censored().country();
    
    private Country detectedCountry = LanternHub.censored().country();
    
    private boolean manualCountry;
    
    public UserInfo() {
        LanternHub.eventBus().register(this);
    }

    public ConnectivityStatus getConnectionState() {
        return connectivityStatus;
    }
    
    public void setConnectionState(final ConnectivityStatus connectivityStatus) {
    }
    
    public String getEmail() {
        return LanternUtils.getEmail();
    }

    public void setEmail(final String email) {
    }
    
    public boolean isPasswordSaved() {
        return StringUtils.isNotBlank(LanternUtils.getPassword());
    }
    
    public void setPasswordSaved(final boolean saved) {
    }
    
    public String getMode() {
        // Lazy-initialize mode to the default
        if (StringUtils.isBlank(mode)) {
            this.mode = LanternUtils.shouldProxy() ? "get" : "give";
        }
        return this.mode;
    }
    
    public void setMode(final String mode) {
        this.mode = mode;
    }

    public void setAuthenticationStatus(
        final AuthenticationStatus authenticationStatus) {
        this.authenticationStatus = authenticationStatus;
    }

    public AuthenticationStatus getAuthenticationStatus() {
        return authenticationStatus;
    }

    @Subscribe
    public void onConnectivityStateChanged(
        final ConnectivityStatusChangeEvent csce) {
        this.connectivityStatus = csce.getConnectivityStatus();
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

    public void setManualCountry(final boolean manualCountry) {
        this.manualCountry = manualCountry;
    }

    public boolean isManualCountry() {
        return manualCountry;
    }

    public void setDetectedCountry(final Country detectedCountry) {
        this.detectedCountry = detectedCountry;
    }

    public Country getDetectedCountry() {
        return detectedCountry;
    }

}
