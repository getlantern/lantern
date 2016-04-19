package org.getlantern.lantern.model;

import android.content.Context;
import android.content.SharedPreferences;
import android.net.ConnectivityManager;
import android.util.Log;

import com.google.android.gms.analytics.GoogleAnalytics;
import com.google.android.gms.analytics.HitBuilders;
import com.google.android.gms.analytics.Tracker;

import java.util.HashMap;
import java.util.Map;

import org.lantern.mobilesdk.Lantern;

public class Utils {
    private static final String PREFS_NAME = "LanternPrefs";
    private static final String TAG = "Utils";
    private static final String PREF_USE_VPN = "pref_vpn";

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

    public static void sendFeedEvent(Context context, String category) {
        Log.d(TAG, "Logging feed event. Category is " + category);

        String analyticsTrackingID = "UA-21815217-14";
        Lantern.trackerFor(context, analyticsTrackingID).send(new HitBuilders.EventBuilder()
                .setCategory(category)
                .setAction("click")
                .build());
    }
}
