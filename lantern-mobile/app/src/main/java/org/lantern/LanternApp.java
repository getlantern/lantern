package org.lantern;

import android.app.Application;

import com.crashlytics.android.Crashlytics;
import io.fabric.sdk.android.Fabric;

import org.lantern.activity.ProResponse;
import org.lantern.model.ProRequest;
import org.lantern.model.SessionManager;


public class LanternApp extends Application implements ProResponse {
    private static final String TAG = "LanternApp";
    private static SessionManager session;

    @Override
    public void onCreate() {
        super.onCreate();
        Fabric.with(this, new Crashlytics());
        session = new SessionManager(getApplicationContext());
        new ProRequest(this).execute("newuser");
    }

    @Override
    public void onSuccess() {

    }

    @Override
    public void onError() {

    }

    public static SessionManager getSession() {
        return session;
    }
}
