package org.getlantern.lantern;

import android.app.Application;
import android.app.Activity;
import android.content.Context;
import android.os.Bundle;
import android.util.Log;

import com.crashlytics.android.Crashlytics;
import io.fabric.sdk.android.Fabric;

public class LanternApp extends Application {
    private static final String TAG = "LanternApp";

    @Override
    public void onCreate() {
        Fabric.with(this, new Crashlytics());
    }
}
