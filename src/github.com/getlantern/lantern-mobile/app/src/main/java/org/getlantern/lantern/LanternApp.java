package org.getlantern.lantern;

import android.app.Application;
import android.app.Activity;
import android.os.Bundle;
import android.util.Log;

import com.crashlytics.android.Crashlytics;
import io.fabric.sdk.android.Fabric;

import org.lantern.mobilesdk.Lantern;
import org.lantern.mobilesdk.LanternNotRunningException;

public class LanternApp extends Application implements Application.ActivityLifecycleCallbacks {
    private static final String TAG = "LanternApp";

    @Override
    public void onCreate() {
        registerActivityLifecycleCallbacks(this);
        Fabric.with(this, new Crashlytics());
    }

    public void onActivityResumed(Activity activity) {
        Log.d(TAG, "Activity resumed");
        try {
            // Any time that we resume an activity, make sure that Lantern is running so that our
            // requests are proxied.
            int startTimeoutMillis = 60000;
            String analyticsTrackingID = ""; // don't track analytics since those are already being tracked elsewhere
            Lantern.enable(getApplicationContext(), startTimeoutMillis, analyticsTrackingID);
        } catch (LanternNotRunningException lnre) {
            throw new RuntimeException("Lantern failed to start: " + lnre.getMessage(), lnre);
        }
    }

    // Below unused
    public void onActivityCreated(Activity activity, Bundle savedInstanceState) {}

    public void onActivityDestroyed(Activity activity) {}

    public void onActivityPaused(Activity activity) {}

    public void onActivitySaveInstanceState(Activity activity, Bundle outState) {}

    public void onActivityStarted(Activity activity) {}

    public void onActivityStopped(Activity activity) {}






}
