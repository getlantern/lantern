package org.lantern;

import org.codehaus.jackson.annotate.JsonPropertyOrder;

/**
 * Top level class containing all user settings.
 */
@JsonPropertyOrder({"user", "system", "whitelist", "roster"})
public class Settings {

    private SystemInfo systemInfo = LanternHub.systemInfo();
    
    private UserInfo userInfo = LanternHub.userInfo();
    
    private Whitelist whitelist = LanternHub.whitelist();
    
    private Roster roster = LanternHub.roster();

    public SystemInfo getSystem() {
        return systemInfo;
    }
    
    public void setSystem(final SystemInfo systemInfo) {
        this.systemInfo = systemInfo;
    }

    public void setUser(final UserInfo userInfo) {
        this.userInfo = userInfo;
    }

    public UserInfo getUser() {
        return userInfo;
    }
    
    public Whitelist getWhitelist() {
        return whitelist;
    }

    public void setWhitelist(final Whitelist whitelist) {
        this.whitelist = whitelist;
    }

    public void setRoster(final Roster roster) {
        this.roster = roster;
    }

    public Roster getRoster() {
        return roster;
    }
}
