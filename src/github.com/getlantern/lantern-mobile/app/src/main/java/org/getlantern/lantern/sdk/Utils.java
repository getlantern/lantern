package org.getlantern.lantern.sdk;

import android.content.Context;
import android.content.SharedPreferences;
import android.net.ConnectivityManager;

public class Utils {
    private static final String PREFS_NAME = "LanternPrefs";
    private static final String TAG = "Utils";
    private final static String PREF_USE_VPN = "pref_vpn";

    // update START/STOP power Lantern button
    // according to our stored preference
    public static SharedPreferences getSharedPrefs(Context context) {
        return context.getSharedPreferences(PREFS_NAME,
                Context.MODE_PRIVATE);
    }

    public static void clearPreferences(Context context) {
        SharedPreferences mPrefs = getSharedPrefs(context);

        if (mPrefs != null) {
            mPrefs.edit().remove(PREF_USE_VPN).commit();
        }
    }

    // isNetworkAvailable checks whether or not we are connected to
    // the Internet; if no connection is available, the toggle
    // switch is inactive
    public static boolean isNetworkAvailable(final Context context) {
        final ConnectivityManager connectivityManager = 
            ((ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE));
        return connectivityManager.getActiveNetworkInfo() != null && 
            connectivityManager.getActiveNetworkInfo().isConnectedOrConnecting();
    }
}
