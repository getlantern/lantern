package org.getlantern.lantern;

import android.app.Application;

import com.crashlytics.android.Crashlytics;
import io.fabric.sdk.android.Fabric;

import org.getlantern.lantern.model.SessionManager;

public class LanternApp extends Application {
    private static final String TAG = "LanternApp";
    private static SessionManager session;

    @Override
    public void onCreate() {
        super.onCreate();
        Fabric.with(this, new Crashlytics());
        session = new SessionManager(getApplicationContext());
    }

    public static SessionManager getSession() {
        return session;
    }
}
