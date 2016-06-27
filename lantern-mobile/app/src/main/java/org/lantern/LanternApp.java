package org.lantern;

import android.app.Application;
import android.content.Context;
import android.os.Handler;
import android.util.Log;

import com.crashlytics.android.Crashlytics;
import io.fabric.sdk.android.Fabric;

import org.lantern.model.ProPlan;
import org.lantern.model.ProRequest;
import org.lantern.model.SessionManager;
import org.lantern.pubsub.Client;
import org.lantern.pubsub.PubSub;

public class LanternApp extends Application {
    private static final String TAG = "LanternApp";
    private static SessionManager session;

    @Override
    public void onCreate() {
        super.onCreate();

        Fabric.with(this, new Crashlytics());
		final Context context = getApplicationContext();
        session = new SessionManager(context);
        session.shouldProxy();
        PubSub.start(context);
        PubSub.subscribe(context, Client.utf8(session.Token()));
    }

    public static SessionManager getSession() {
        return session;
    }
}
