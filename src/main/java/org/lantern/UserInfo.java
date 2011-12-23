package org.lantern;

import org.apache.commons.lang.StringUtils;

/**
 * Data about the user.
 */
public class UserInfo implements ConnectivityListener {
    
    private AuthenticationStatus authenticationStatus = 
        AuthenticationStatus.LOGGED_OUT;
    
    private ConnectivityStatus connectivityStatus = 
        LanternHub.pubSub().getConnectivityStatus();

    private String mode = LanternUtils.shouldProxy() ? "get" : "give";
    
    public UserInfo() {
        LanternHub.pubSub().addConnectivityListener(this);
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

    @Override
    public void onConnectivityStateChanged(final ConnectivityStatus cs) {
        this.connectivityStatus = cs;
    }

}
