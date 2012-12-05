package org.lantern.state;

/**
 * The available channels to sync on.
 */
public enum SyncPath {
    CONNECTIVITY_GTALK("connectivity.gtalk"), 
    SETTINGS("settings"), 
    VERSION_UPDATED("version.updated"), 
    ROSTER("roster"), 
    MODAL("modal"), 
    ALL(""), 
    PROFILE("profile");
    
    private final String enumPath;

    private SyncPath(final String path) {
        enumPath = path;
    }

    public String getEnumPath() {
        return enumPath;
    }
}