package org.getlantern.lantern.model;

import android.content.Context;
import android.content.SharedPreferences;

import org.getlantern.lantern.config.LanternConfig;

public class Utils {
    private static final String PREFS_NAME = "LanternPrefs";

    // update START/STOP power Lantern button
    // according to our stored preference
    public static SharedPreferences getSharedPrefs(Context context) {
        return context.getSharedPreferences(PREFS_NAME,
                Context.MODE_PRIVATE);
    }

    public static void clearPreferences(Context context) {

        SharedPreferences mPrefs = getSharedPrefs(context);

        if (mPrefs != null) {
            mPrefs.edit().remove(LanternConfig.PREF_USE_VPN);
            mPrefs.edit().clear().commit();
        }
    }
}
