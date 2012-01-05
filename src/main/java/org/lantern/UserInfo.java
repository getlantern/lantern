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

    private Mode mode = 
        LanternHub.censored().isCensored() ? Mode.GET : Mode.GIVE;
    
    private boolean proxyAllSites;
    
    private Country country = LanternHub.censored().country();
    
    private Country detectedCountry = LanternHub.censored().country();
    
    private boolean manuallyOverrideCountry;
    
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
    
    public Mode getMode() {
        // Lazy-initialize mode to the default
        if (mode == null) {
            this.mode = LanternHub.censored().isCensored() ? Mode.GET : Mode.GIVE;
        }
        return this.mode;
    }
    
    @Override
    public void setMode(final Mode mode) {
        this.mode = mode;
    }

    public void setAuthenticationStatus(
        final AuthenticationStatus authenticationStatus) {
    }

    public AuthenticationStatus getAuthenticationStatus() {
        return authenticationStatus;
    }
    
    @Subscribe
    public void onAuthenticationStateChanged(
        final AuthenticationStatusEvent ase) {
        this.authenticationStatus = ase.getStatus();
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

    public void setDetectedCountry(final Country detectedCountry) {
        this.detectedCountry = detectedCountry;
    }

    public Country getDetectedCountry() {
        return detectedCountry;
    }

    public void setManuallyOverrideCountry(boolean manuallyOverrideCountry) {
        this.manuallyOverrideCountry = manuallyOverrideCountry;
    }

    public boolean isManuallyOverrideCountry() {
        return manuallyOverrideCountry;
    }

}
