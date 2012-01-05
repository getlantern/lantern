package org.lantern;

import org.codehaus.jackson.annotate.JsonIgnore;

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
    
    private String email;
    
    private String password;
    
    private String storedPassword;
    
    private boolean savePassword = true;
    
    public UserInfo() {
        LanternHub.eventBus().register(this);
    }

    public ConnectivityStatus getConnectionState() {
        return connectivityStatus;
    }
    
    public void setConnectionState(final ConnectivityStatus connectivityStatus) {
        // We ignore the value from disk and rely on the event dispatch system.
    }
    
    public String getEmail() {
        //return LanternUtils.getEmail();
        return email;
    }

    public void setEmail(final String email) {
        this.email = email;
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

}
