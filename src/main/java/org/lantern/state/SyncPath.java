package org.lantern.state;


/**
 * The available channels to sync on.
 */
public enum SyncPath {
    SETTINGS("settings"), 
    VERSION_UPDATED("version.latest"), 
    ROSTER("roster"), 
    MODAL("modal"), 
    ALL(""), 
    PROFILE("profile"), 
    MODE("settings.mode"),
    CONNECTIVITY_GTALK("connectivity.gtalk"), 
    PEERS("connectivity.peers"), 
    INVITED("connectivity.invited"), 
    NINVITES("ninvites"), 
    START_AT_LOGIN("settings.startAtLogin"),
    AUTO_CONNECT("settings.autoConnect"),
    AUTO_REPORT("settings.autoReport"),
    PROXY_ALL_SITES("settings.proxyAllSites");
    
    private final String path;
    
    private SyncPath(final String path) {
        this.path = path;
        // We do a dummy check here to make sure to catch any bogus paths.
        // The check doesn't work with enum properties unfortunately.
        /*
        try {
            final Object obj = LanternUtils.getTargetForPath(model, path);
            if (obj == null) {
                throw new Error("Path is invalid for model: "+path);
            }
        } catch (final IllegalAccessException e) {
            throw new Error("Path is invalid for model: "+path, e);
        } catch (final InvocationTargetException e) {
            throw new Error("Path is invalid for model: "+path, e);
        } catch (final NoSuchMethodException e) {
            throw new Error("Path is invalid for model: "+path, e);
        }
        */
    }

    public String getPath() {
        return path;
    }
}