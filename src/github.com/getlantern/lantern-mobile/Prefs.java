
package org.torproject.android;

import android.content.Context;
import android.content.SharedPreferences;
import org.torproject.android.service.TorServiceUtils;

import java.util.Locale;

public class Prefs {
    private final static String PREF_BRIDGES_ENABLED = "pref_bridges_enabled";
    private final static String PREF_BRIDGES_LIST = "pref_bridges_list";
    private final static String PREF_DEFAULT_LOCALE = "pref_default_locale";
    private final static String PREF_ENABLE_LOGGING = "pref_enable_logging";
    private final static String PREF_EXPANDED_NOTIFICATIONS = "pref_expanded_notifications";
    private final static String PREF_HAS_ROOT = "has_root";
    private final static String PREF_PERSIST_NOTIFICATIONS = "pref_persistent_notifications";
    private final static String PREF_START_ON_BOOT = "pref_start_boot";
    private final static String PREF_ALLOW_BACKGROUND_STARTS = "pref_allow_background_starts";
    private final static String PREF_TRANSPARENT = "pref_transparent";
    private final static String PREF_TRANSPARENT_ALL = "pref_transparent_all";
    private final static String PREF_TRANSPARENT_TETHERING = "pref_transparent_tethering";
    private final static String PREF_TRANSPROXY_REFRESH = "pref_transproxy_refresh";
    private final static String PREF_USE_SYSTEM_IPTABLES = "pref_use_sys_iptables";
    private final static String PREF_USE_VPN = "pref_vpn";

    private static SharedPreferences prefs;

    public static void setContext(Context context) {
        if (prefs == null)
            prefs = TorServiceUtils.getSharedPrefs(context);
    }

    private static void putBoolean(String key, boolean value) {
        prefs.edit().putBoolean(key, value).apply();
    }

    private static void putString(String key, String value) {
        prefs.edit().putString(key, value).apply();
    }

    public static boolean bridgesEnabled() {
        return prefs.getBoolean(PREF_BRIDGES_ENABLED, false);
    }

    public static void putBridgesEnabled(boolean value) {
        putBoolean(PREF_BRIDGES_ENABLED, value);
    }

    public static String getBridgesList() {
        return prefs.getString(PREF_BRIDGES_LIST, "");
    }

    public static void setBridgesList(String value) {
        putString(PREF_BRIDGES_LIST, value);
    }

    public static String getDefaultLocale() {
        return prefs.getString(PREF_DEFAULT_LOCALE, Locale.getDefault().getLanguage());
    }

    public static void setDefaultLocale(String value) {
        putString(PREF_DEFAULT_LOCALE, value);
    }

    public static boolean useSystemIpTables() {
        return prefs.getBoolean(PREF_USE_SYSTEM_IPTABLES, false);
    }

    public static boolean useRoot() {
        return prefs.getBoolean(PREF_HAS_ROOT, false);
    }

    public static boolean useTransparentProxying() {
        return prefs.getBoolean(PREF_TRANSPARENT, false);
    }

    public static boolean transparentProxyAll() {
        return prefs.getBoolean(PREF_TRANSPARENT_ALL, false);
    }

    public static boolean transparentTethering() {
        return prefs.getBoolean(PREF_TRANSPARENT_TETHERING, false);
    }

    public static boolean transProxyNetworkRefresh() {
        return prefs.getBoolean(PREF_TRANSPROXY_REFRESH, false);
    }

    public static boolean expandedNotifications() {
        return prefs.getBoolean(PREF_EXPANDED_NOTIFICATIONS, false);
    }

    public static boolean useDebugLogging() {
        return prefs.getBoolean(PREF_ENABLE_LOGGING, false);
    }

    public static boolean persistNotifications() {
        return prefs.getBoolean(PREF_PERSIST_NOTIFICATIONS, true);
    }

    public static boolean allowBackgroundStarts() {
        return prefs.getBoolean(PREF_ALLOW_BACKGROUND_STARTS, true);
    }

    public static boolean useVpn() {
        return prefs.getBoolean(PREF_USE_VPN, false);
    }

    public static void putUseVpn(boolean value) {
        putBoolean(PREF_USE_VPN, value);
    }

    public static boolean startOnBoot() {
        return prefs.getBoolean(PREF_START_ON_BOOT, true);
    }

    public static void putStartOnBoot(boolean value) {
        putBoolean(PREF_START_ON_BOOT, value);
    }
}
