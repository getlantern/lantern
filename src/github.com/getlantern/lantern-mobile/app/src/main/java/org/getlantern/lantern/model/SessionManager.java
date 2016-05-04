package org.getlantern.lantern.model;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.os.AsyncTask;
import android.util.Log;

import java.util.HashMap;
import java.util.Locale;

import org.getlantern.lantern.activity.LanternMainActivity;
import org.lantern.mobilesdk.StartResult;
import org.lantern.mobilesdk.LanternNotRunningException;
import org.getlantern.lantern.vpn.Service;

public class SessionManager {

    private static final String TAG = "SessionManager";

    private static final String PREFS_NAME = "LanternPrefs";
    private static final String PREF_USE_VPN = "pref_vpn";
    private static final String PREF_NEWSFEED = "pref_newsfeed";

     // shared preferences mode
    private int PRIVATE_MODE = 0;

    private Context mContext;
    private SharedPreferences mPrefs;
    private Editor editor;

    public SessionManager(Context context) {
        this.mContext = context;
        this.mPrefs = context.getSharedPreferences(PREFS_NAME, PRIVATE_MODE);
        this.editor = mPrefs.edit();
        if (showFeed()) {
            // if the news feed should be shown
            // start a local proxy before retrieving it
            startLocalProxy();
        }
    }

    public boolean useVpn() {
        return mPrefs.getBoolean(PREF_USE_VPN, false);
    }

    public void updateVpnPreference(boolean useVpn) {
        editor.putBoolean(PREF_USE_VPN, useVpn).commit();
    }

    public void updateFeedPreference(boolean pref) {
        editor.putBoolean(PREF_NEWSFEED, pref).commit();
    }   

    public boolean showFeed() {
        return mPrefs.getBoolean(PREF_NEWSFEED, true);
    }

    public void clearVpnPreference() {
        editor.putBoolean(PREF_USE_VPN, false).commit();
    }

    // startLocalProxy starts a separate instance of Lantern
    // used for proxying requests we need to make even before
    // the user enables full-device VPN mode
    public String startLocalProxy() {

        // if the Lantern VPN is already running
        // then we just fetch the feed without
        // starting another local proxy
        if (Service.isRunning(mContext)) {
            return "";
        }

        try {
            int startTimeoutMillis = 60000;
            String analyticsTrackingID = ""; // don't track analytics since those are already being tracked elsewhere
            boolean updateProxySettings = true;

            StartResult result = org.lantern.mobilesdk.Lantern.enable(mContext, 
                startTimeoutMillis, updateProxySettings, analyticsTrackingID);
            return result.getHTTPAddr();
        }  catch (LanternNotRunningException lnre) {
            throw new RuntimeException("Lantern failed to start: " + lnre.getMessage(), lnre);
        }  
    }
}
