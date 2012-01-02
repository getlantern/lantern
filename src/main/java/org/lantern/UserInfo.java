package org.lantern;

import org.apache.commons.lang.StringUtils;

import com.google.common.eventbus.Subscribe;

/**
 * Data about the user.
 */
public class UserInfo {
    
    private AuthenticationStatus authenticationStatus = 
        AuthenticationStatus.LOGGED_OUT;
    
    private ConnectivityStatus connectivityStatus = 
        ConnectivityStatus.DISCONNECTED;

    private String mode;
    
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

}
