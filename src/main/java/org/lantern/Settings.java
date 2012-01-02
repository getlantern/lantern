package org.lantern;

import org.codehaus.jackson.annotate.JsonPropertyOrder;

/**
 * Top level class containing all user settings.
 */
@JsonPropertyOrder({"user", "system", "whitelist", "roster"})
public class Settings {

    private SystemInfo systemInfo;
    
    private UserInfo userInfo;
    
    private Whitelist whitelist;
    
    private Roster roster;
    
    public Settings() {
    }
    
    public Settings(final SystemInfo system, final UserInfo user, 
        final Whitelist whitelist, final Roster roster) {
        this.systemInfo = system;
        this.userInfo = user;
        this.whitelist = whitelist;
        this.roster = roster;
    }

    public SystemInfo getSystem() {
        //if (this.systemInfo == null) {
        //    systemInfo = LanternHub.systemInfo();
        //}
        return systemInfo;
    }
    
    public void setSystem(final SystemInfo systemInfo) {
        this.systemInfo = systemInfo;
    }

    public void setUser(final UserInfo userInfo) {
        this.userInfo = userInfo;
    }

    public UserInfo getUser() {
        //if (this.userInfo == null) {
        //    this.userInfo = LanternHub.userInfo();
        //}
        return userInfo;
    }
    
    public Whitelist getWhitelist() {
        //if (this.whitelist == null) {
        //    this.whitelist = LanternHub.whitelist();
       // }
        return whitelist;
    }

    public void setWhitelist(final Whitelist whitelist) {
        this.whitelist = whitelist;
    }

    public void setRoster(final Roster roster) {
        this.roster = roster;
    }

    public Roster getRoster() {
        //if (this.roster == null) {
        //    this.roster = LanternHub.roster();
        //}
        return roster;
    }
}
