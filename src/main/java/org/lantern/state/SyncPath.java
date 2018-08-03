package org.lantern.state;


/**
 * The available channels to sync on.
 */
public enum SyncPath {
    SETTINGS("settings"),
    VERSION("version"),
    VERSION_LATEST("version/latest"),
    VERSION_UPDATE_AVAILABLE("version/updateAvailable"),
    ROSTER("roster"),
    MODAL("modal"),
    ALL(""),
    PROFILE("profile"),
    MODE("settings/mode"),
    CONNECTIVITY_GTALK("connectivity/gtalk"),
    CONNECTING_STATUS("connectivity/connectingStatus"),
    CONNECTIVITY_INTERNET("connectivity/internet"),
    CONNECTIVITY("connectivity"),
    CONNECTIVITY_LANTERN_CONTROLLER("connectivity/lanternController"),
    CONNECTIVITY_NPROXIES("connectivity/nproxies"),
    PEERS("peers"),
    INVITED("connectivity/invited"),
    START_AT_LOGIN("settings/startAtLogin"),
    AUTO_CONNECT("settings/autoConnect"),
    AUTO_REPORT("settings/autoReport"),
    SHOW_FRIEND_PROMPTS("settings/showFriendPrompts"),
    PROXY_ALL_SITES("settings/proxyAllSites"),
    SYSTEMPROXY("settings/systemProxy"),
    LOCATION("location"),
    TRANSFERS("transfers"),
    GLOBAL("global"),
    COUNTRIES("countries"),
    NOTIFICATIONS("notifications"),
    SETUPCOMPLETE("setupComplete"),
    SHOWVIS("showVis"),
    FRIENDS("friends"),
    FRIENDING_QUOTA("remainingFriendingQuota");

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
