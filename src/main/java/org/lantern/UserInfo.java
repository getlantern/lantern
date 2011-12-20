package org.lantern;

import org.apache.commons.lang.StringUtils;

/**
 * Data about the user.
 */
public class UserInfo {
    
    private AuthenticationStatus authenticationStatus = 
        AuthenticationStatus.LOGGED_OUT;

    public ConnectivityStatus getConnectionState() {
        return LanternHub.connectivityTracker().getConnectivityStatus();
    }
    
    public String getEmail() {
        return LanternUtils.getEmail();
    }
    
    public boolean isPasswordSaved() {
        return StringUtils.isNotBlank(LanternUtils.getPassword());
    }
    
    public String getMode() {
        return LanternUtils.shouldProxy() ? "get" : "give";
    }

    public void setAuthenticationStatus(
        final AuthenticationStatus authenticationStatus) {
        this.authenticationStatus = authenticationStatus;
    }

    public AuthenticationStatus getAuthenticationStatus() {
        return authenticationStatus;
    }

}
