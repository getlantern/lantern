package org.lantern;

import android.app.Application;
import android.content.Context;
import android.util.Log;

import com.crashlytics.android.Crashlytics;
import io.fabric.sdk.android.Fabric;

import org.lantern.model.ProPlan;
import org.lantern.model.ProRequest;
import org.lantern.model.SessionManager;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;


public class LanternApp extends Application {
    private static final String TAG = "LanternApp";
    private static SessionManager session;

    @Override
    public void onCreate() {
        super.onCreate();

        if (!EventBus.getDefault().isRegistered(this)) {
            // we don't have to unregister an EventBus if its
            // in the Application class
            EventBus.getDefault().register(this);
        }

        Fabric.with(this, new Crashlytics());
		Context context = getApplicationContext();
        session = new SessionManager(context);
        session.newUser();
		new ProRequest(context, false, null).execute("plans");
    }

    @Subscribe
    public void onEvent(ProPlan plan) {
        Log.d(TAG, "Got a new PLAN: " + plan.getPlanId());
        session.savePlan(getResources(), plan);
    }

    public static SessionManager getSession() {
        return session;
    }
}
