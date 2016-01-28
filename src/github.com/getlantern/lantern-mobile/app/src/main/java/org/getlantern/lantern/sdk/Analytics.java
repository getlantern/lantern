package org.getlantern.lantern.sdk;

import android.content.Context;

import com.google.android.gms.analytics.GoogleAnalytics;
import com.google.android.gms.analytics.HitBuilders;
import com.google.android.gms.analytics.Tracker;

public class Analytics {
    private GoogleAnalytics analytics;
    private Tracker tracker;
    private final String TRACKING_ID = "UA-21815217-14";

    public Analytics(Context context) {
        analytics = GoogleAnalytics.getInstance(context);
        analytics.setLocalDispatchPeriod(1800);

        tracker = analytics.newTracker(TRACKING_ID);
        tracker.enableAdvertisingIdCollection(true);
        tracker.enableAutoActivityTracking(true);
    }

    public void sendNewSessionEvent() {
        tracker.send(new HitBuilders.EventBuilder()
                .setCategory("Session")
                .setAction("Start")
                .setLabel("android")
                .build());
    }

    public void trackLoginEvent(String type) {
        tracker.send(new HitBuilders.EventBuilder()
                .setCategory("Session")
                .setAction("Login")
                .setLabel(type)
                .build());
    }

    public void trackPageView(String pageName) {
        tracker.send(new HitBuilders.EventBuilder()
                .setCategory("Session")
                .setAction("PageView")
                .setLabel(pageName)
                .build());
    }
}
